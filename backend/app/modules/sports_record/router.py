from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.responses import FileResponse
from pathlib import Path
import os, re
from app.core.dependencies import get_current_athlete, get_current_user
from . import service as s, repository as r
from .schemas import *

router=APIRouter(prefix='/v1',tags=['sports-record','evidence'])

def fail(exc): return HTTPException(status_code=exc.status,detail={'code':exc.code,'message':exc.message,'details':[]})
def wrap(data,request): return {'data':data,'meta':{'next_cursor':None,'request_id':request.state.request_id}}
def call(fn,*args,**kwargs):
 try:return fn(*args,**kwargs)
 except s.DomainError as e:raise fail(e)

@router.get('/me/performance')
def my_performance(request:Request,metric_key:str|None=None,user=Depends(get_current_athlete)):
 return wrap(s.list_performance(user['user_id'],metric_key),request)
@router.post('/performance',status_code=201)
def add_performance(body:PerformanceCreate,request:Request,user=Depends(get_current_athlete)):
 return wrap(call(s.create_performance,user['user_id'],body),request)
@router.get('/performance/{public_id}')
def performance_detail(public_id:str,request:Request,user=Depends(get_current_athlete)):
 item=next((x for x in s.list_performance(user['user_id']) if x['public_id']==public_id),None)
 if not item: raise HTTPException(404,detail={'code':'NOT_FOUND','message':'Performance record not found','details':[]})
 return wrap(item,request)
@router.patch('/performance/{public_id}')
def edit_performance(public_id:str,body:PerformancePatch,request:Request,user=Depends(get_current_athlete)):
 return wrap(call(s.patch_performance,user['user_id'],public_id,body),request)
@router.delete('/performance/{public_id}',status_code=204)
def remove_performance(public_id:str,user=Depends(get_current_athlete)):
 call(s.delete_performance,user['user_id'],public_id); return Response(status_code=204)
@router.get('/athletes/{sportsz_id}/stats')
def public_stats(sportsz_id:str,request:Request,user=Depends(get_current_athlete)):
 # Public profile identifier is resolved through M1's sports_ids collection; never query another owner's records by arbitrary user id.
 from app.core.database import sports_ids_collection
 identity=sports_ids_collection.find_one({'sportsz_id':sportsz_id})
 if not identity: raise HTTPException(404,detail={'code':'NOT_FOUND','message':'Athlete not found','details':[]})
 rows=r.performance_entries.find({'user_id':identity['user_id'],'verification_status':'verified'}).sort('recorded_at',-1).limit(100)
 return wrap([{k:v for k,v in x.items() if k not in ('_id','user_id','notes','evidence_media_id')} for x in rows],request)
@router.get('/me/metric-bests')
def metric_best(request:Request,sport_id:str|None=None,user=Depends(get_current_athlete)):
 return wrap(s.read_metric_bests(user['user_id'],sport_id),request)

@router.get('/me/achievements')
def my_achievements(request:Request,user=Depends(get_current_athlete)): return wrap(s.list_achievements(user['user_id']),request)
@router.post('/achievements',status_code=201)
def add_achievement(body:AchievementCreate,request:Request,user=Depends(get_current_athlete)): return wrap(call(s.create_achievement,user['user_id'],body),request)
@router.get('/achievements/{public_id}')
def achievement_detail(public_id:str,request:Request,user=Depends(get_current_athlete)):
 item=next((x for x in s.list_achievements(user['user_id']) if x['public_id']==public_id),None)
 if not item:raise HTTPException(404,detail={'code':'NOT_FOUND','message':'Achievement not found','details':[]})
 return wrap(item,request)
@router.patch('/achievements/{public_id}')
def edit_achievement(public_id:str,body:AchievementPatch,request:Request,user=Depends(get_current_athlete)):return wrap(call(s.update_achievement,user['user_id'],public_id,body),request)
@router.delete('/achievements/{public_id}',status_code=204)
def remove_achievement(public_id:str,user=Depends(get_current_athlete)):call(s.delete_achievement,user['user_id'],public_id);return Response(status_code=204)

for kind, prefix in [('media','media'),('documents','documents')]:
 def make_upload(k):
  @router.post(f'/{k}/upload-url',status_code=201)
  def upload_url(body:UploadRequest,request:Request,user=Depends(get_current_athlete)):return wrap(call(s.create_upload,user['user_id'],k,body),request)
  @router.post(f'/{k}/{{upload_id}}/confirm')
  def confirm(upload_id:str,request:Request,user=Depends(get_current_athlete)):return wrap(call(s.confirm_upload,user['user_id'],k,upload_id),request)
  @router.get(f'/me/{k}')
  def listing(request:Request,user=Depends(get_current_athlete)):return wrap(s.list_assets(user['user_id'],k),request)
  @router.get(f'/{k}/{{public_id}}')
  def detail(public_id:str,request:Request,user=Depends(get_current_athlete)):return wrap(call(s.get_asset,user['user_id'],k,public_id),request)
  @router.delete(f'/{k}/{{public_id}}',status_code=204)
  def delete(public_id:str,user=Depends(get_current_athlete)):call(s.delete_asset,user['user_id'],k,public_id);return Response(status_code=204)
  return upload_url
 make_upload(kind)

@router.put('/storage/{kind}/{upload_id}')
async def local_upload(kind:str,upload_id:str,request:Request,user=Depends(get_current_athlete)):
 if kind not in ('media','documents'): raise HTTPException(404)
 item=call(s.get_asset,user['user_id'],kind,upload_id)
 body=await request.body()
 if len(body)!=item['size_bytes']:raise HTTPException(422,detail={'code':'SIZE_MISMATCH','message':'Uploaded bytes do not match declared size','details':[]})
 if request.headers.get('content-type','').split(';')[0]!=item['content_type']:raise HTTPException(422,detail={'code':'MIME_MISMATCH','message':'Content-Type mismatch','details':[]})
 # Store outside the repository; production deployments should replace this local adapter with private MinIO/S3 + ClamAV.
 base=Path(os.getenv('M5_LOCAL_STORAGE_DIR','./var/m5_uploads')).resolve();base.mkdir(parents=True,exist_ok=True)
 safe_name=re.sub(r'[^a-zA-Z0-9_.-]','_',item['filename']); path=(base/f'{upload_id}_{safe_name}').resolve()
 if base not in path.parents:raise HTTPException(400)
 path.write_bytes(body)
 col=r.media if kind=='media' else r.documents
 col.update_one({'public_id':upload_id,'user_id':user['user_id']},{'$set':{'storage_key':str(path),'status':'uploaded','updated_at':r.utcnow()}})
 return {'data':{'uploaded':True},'meta':{'request_id':request.state.request_id,'next_cursor':None}}

@router.get('/media/{public_id}/playback-url')
def playback_url(public_id:str,request:Request,user=Depends(get_current_athlete)):
 item=call(s.get_asset,user['user_id'],'media',public_id)
 if item['status']!='uploaded':raise HTTPException(409,detail={'code':'NOT_READY','message':'Media is not ready','details':[]})
 return wrap({'url':f"/v1/media/{public_id}/stream",'expires_in':300},request)
@router.get('/media/{public_id}/stream')
def stream_media(public_id:str,user=Depends(get_current_athlete)):
 item=call(s.get_asset,user['user_id'],'media',public_id); path=r.find_asset_storage_key('media',public_id,user['user_id'])
 if not path or not Path(path).is_file():raise HTTPException(404)
 return FileResponse(path,media_type=item['content_type'],filename=item['filename'])
@router.get('/documents/{public_id}/url')
def document_url(public_id:str,request:Request,user=Depends(get_current_athlete)):
 item=call(s.get_asset,user['user_id'],'documents',public_id)
 if item['status']!='uploaded':raise HTTPException(409,detail={'code':'NOT_READY','message':'Document is not ready','details':[]})
 return wrap({'url':f"/v1/documents/{public_id}/download",'expires_in':300},request)
@router.get('/documents/{public_id}/download')
def download_document(public_id:str,user=Depends(get_current_athlete)):
 item=call(s.get_asset,user['user_id'],'documents',public_id);path=r.find_asset_storage_key('documents',public_id,user['user_id'])
 if not path or not Path(path).is_file():raise HTTPException(404)
 return FileResponse(path,media_type='application/octet-stream',filename=item['filename'])

@router.post('/verification',status_code=201)
def request_verification(body:VerificationCreate,request:Request,user=Depends(get_current_athlete)):return wrap(call(s.create_verification,user['user_id'],body),request)
@router.get('/me/verification')
def my_verification(request:Request,user=Depends(get_current_athlete)):return wrap(s.list_verification(user['user_id']),request)
@router.get('/me/verification/{public_id}')
def verification_detail(public_id:str,request:Request,user=Depends(get_current_athlete)):return wrap(call(s.get_verification,user['user_id'],public_id),request)
@router.post('/me/verification/{public_id}/resubmit')
def verification_resubmit(public_id:str,request:Request,user=Depends(get_current_athlete)):return wrap(call(s.resubmit,user['user_id'],public_id),request)
@router.get('/admin/verification')
def admin_verification(request:Request,status:str='pending',user=Depends(get_current_user)):
 if user.get('role')!='admin':raise HTTPException(403,detail={'code':'FORBIDDEN','message':'Admin role required','details':[]})
 return wrap([{k:v for k,v in x.items() if k!='_id'} for x in r.verification_requests.find({'status':status}).sort('created_at',1).limit(100)],request)
@router.post('/admin/verification/{public_id}/decide')
def decide(public_id:str,body:VerificationDecision,request:Request,user=Depends(get_current_user)):
 if user.get('role')!='admin':raise HTTPException(403,detail={'code':'FORBIDDEN','message':'Admin role required','details':[]})
 return wrap(call(s.decide_verification,public_id,user['user_id'],body),request)
