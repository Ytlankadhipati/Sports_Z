"""M5 domain services. Source/verification fields are server-owned."""
from datetime import datetime, timezone
from uuid import uuid4
from bson import ObjectId
from pymongo import ReturnDocument
from . import repository as r

class DomainError(Exception):
 def __init__(self,status,code,message): self.status=status; self.code=code; self.message=message

def public(doc):
 if not doc:return None
 x=dict(doc); x.pop("_id",None); x.pop("storage_key",None); return x
def _get(col,pid,uid=None):
 q={"public_id":pid}
 if uid is not None:q["user_id"]=uid
 return col.find_one(q)
def list_performance(uid,metric=None):
 q={"user_id":uid}
 if metric:q["metric_key"]=metric
 return [public(x) for x in r.performance_entries.find(q).sort("recorded_at",-1).limit(200)]
def validate_metric(data):
 """Validate metric against M1 sport config when a metric definition exists."""
 from app.core.database import sports_collection
 sport=sports_collection.find_one({"$or":[{"sport_id":data.sport_id},{"id":data.sport_id},{"_id":data.sport_id}]})
 if not sport: raise DomainError(422,"UNKNOWN_SPORT","Sport is not present in the M1 sports catalog")
 config=sport.get("config") or {}
 metrics=config.get("metrics") or config.get("performance_metrics") or []
 definition=next((m for m in metrics if m.get("key")==data.metric_key or m.get("metric_key")==data.metric_key),None)
 if metrics and definition is None: raise DomainError(422,"UNKNOWN_METRIC","Metric is not configured for this sport")
 if definition:
  expected=definition.get("unit")
  if expected and expected != data.unit: raise DomainError(422,"INVALID_UNIT",f"Expected unit: {expected}")
  minimum=definition.get("min_value"); maximum=definition.get("max_value")
  if minimum is not None and data.value < minimum: raise DomainError(422,"VALUE_OUT_OF_RANGE","Metric value is below configured minimum")
  if maximum is not None and data.value > maximum: raise DomainError(422,"VALUE_OUT_OF_RANGE","Metric value is above configured maximum")
 return definition or {}
def create_performance(uid,data):
 validate_metric(data)
 d=data.model_dump(); d.update(public_id=str(uuid4()),user_id=uid,source="athlete",endorsement={"status":"none"},verification_status="unverified",created_at=r.utcnow(),updated_at=r.utcnow())
 r.performance_entries.insert_one(d); rebuild_metric_best(uid,d["sport_id"],d["metric_key"]); return public(d)
def patch_performance(uid,pid,data):
 old=_get(r.performance_entries,pid,uid)
 if not old: raise DomainError(404,"NOT_FOUND","Performance record not found")
 if old.get("verification_status")=="verified": raise DomainError(409,"VERIFIED_IMMUTABLE","Verified records cannot be edited")
 changes=data.model_dump(exclude_unset=True)
 if not changes: raise DomainError(422,"EMPTY_PATCH","Provide at least one field")
 changes.update(endorsement={"status":"none"},verification_status="unverified",updated_at=r.utcnow())
 r.performance_entries.update_one({"_id":old["_id"]},{"$set":changes})
 updated=r.performance_entries.find_one({"_id":old["_id"]}); rebuild_metric_best(uid,old["sport_id"],old["metric_key"]); return public(updated)
def delete_performance(uid,pid):
 old=_get(r.performance_entries,pid,uid)
 if not old: raise DomainError(404,"NOT_FOUND","Performance record not found")
 if old.get("verification_status")=="verified": raise DomainError(409,"VERIFIED_IMMUTABLE","Verified records cannot be deleted")
 r.performance_entries.delete_one({"_id":old["_id"]}); rebuild_metric_best(uid,old["sport_id"],old["metric_key"]); return True
def rebuild_metric_best(uid,sport,metric):
 rows=list(r.performance_entries.find({"user_id":uid,"sport_id":sport,"metric_key":metric}))
 if not rows: r.metric_bests.delete_one({"user_id":uid,"sport_id":sport,"metric_key":metric}); return
 # Default direction is higher-is-better; sport config can later override via M1 config contract.
 best=max(rows,key=lambda x:float(x["value"]))
 verified=[x for x in rows if x.get("verification_status")=="verified"]
 best_verified=max(verified,key=lambda x:float(x["value"])) if verified else None
 r.metric_bests.update_one({"user_id":uid,"sport_id":sport,"metric_key":metric},{"$set":{"value":best["value"],"unit":best["unit"],"best_verified_value":best_verified["value"] if best_verified else None,"best_verified_entry_id":best_verified["public_id"] if best_verified else None,"updated_at":r.utcnow()}},upsert=True)
def read_metric_bests(uid,sport_id=None):
 q={"user_id":uid}
 if sport_id:q["sport_id"]=sport_id
 return [public(x) for x in r.metric_bests.find(q)]
def create_from_event(uid,sport_id,results,event_id):
 """Idempotent event-result ingestion. results: [{metric_key,value,unit,recorded_at?}]."""
 created=[]
 for item in results:
  key=f"event:{event_id}:{uid}:{item['metric_key']}"
  exists=r.performance_entries.find_one({"idempotency_key":key})
  if exists: created.append(public(exists)); continue
  d={"public_id":str(uuid4()),"idempotency_key":key,"user_id":uid,"sport_id":sport_id,"metric_key":item["metric_key"],"value":float(item["value"]),"unit":item["unit"],"recorded_at":item.get("recorded_at") or r.utcnow(),"source":"event","source_event_id":event_id,"verification_status":"unverified","endorsement":{"status":"none"},"created_at":r.utcnow(),"updated_at":r.utcnow()}
  try:r.performance_entries.insert_one(d)
  except Exception:
   d=r.performance_entries.find_one({"idempotency_key":key})
  rebuild_metric_best(uid,sport_id,item["metric_key"]); created.append(public(d))
 return created
def list_achievements(uid):return [public(x) for x in r.achievements.find({"user_id":uid}).sort("created_at",-1).limit(200)]
def create_achievement(uid,data):
 d=data.model_dump(); d.update(public_id=str(uuid4()),user_id=uid,verification_status="unverified",created_at=r.utcnow(),updated_at=r.utcnow()); r.achievements.insert_one(d); return public(d)
def update_achievement(uid,pid,data):
 old=_get(r.achievements,pid,uid)
 if not old:raise DomainError(404,"NOT_FOUND","Achievement not found")
 changes=data.model_dump(exclude_unset=True); changes.update(verification_status="unverified",updated_at=r.utcnow()); r.achievements.update_one({"_id":old["_id"]},{"$set":changes}); return public(r.achievements.find_one({"_id":old["_id"]}))
def delete_achievement(uid,pid):
 old=_get(r.achievements,pid,uid)
 if not old:raise DomainError(404,"NOT_FOUND","Achievement not found")
 if old.get("verification_status")=="verified":raise DomainError(409,"VERIFIED_IMMUTABLE","Verified achievements cannot be deleted")
 r.achievements.delete_one({"_id":old["_id"]}); return True
def create_upload(uid,kind,data):
 col=r.media if kind=="media" else r.documents
 allowed={"image/jpeg","image/png","image/webp","video/mp4","application/pdf"}
 if data.content_type not in allowed:raise DomainError(422,"UNSUPPORTED_TYPE","Unsupported content type")
 if kind=="documents" and data.content_type not in {"image/jpeg","image/png","application/pdf"}:raise DomainError(422,"UNSUPPORTED_TYPE","Documents must be PDF/JPEG/PNG")
 pid=str(uuid4()); d={"public_id":pid,"user_id":uid,"filename":data.filename,"content_type":data.content_type,"size_bytes":data.size_bytes,"purpose":data.purpose,"status":"awaiting_upload","created_at":r.utcnow(),"updated_at":r.utcnow()}
 col.insert_one(d)
 # Storage adapter contract: configure S3-compatible endpoint in production. Local mode returns API upload route.
 return {"upload_id":pid,"upload_url":f"/v1/storage/{kind}/{pid}","method":"PUT","headers":{"Content-Type":data.content_type},"expires_in":900,"storage_mode":"local_dev"}
def confirm_upload(uid,kind,pid):
 col=r.media if kind=="media" else r.documents; d=_get(col,pid,uid)
 if not d:raise DomainError(404,"NOT_FOUND","Upload not found")
 if d["status"] not in ("awaiting_upload","uploaded"):raise DomainError(409,"INVALID_STATE","Upload cannot be confirmed")
 col.update_one({"_id":d["_id"]},{"$set":{"status":"uploaded","updated_at":r.utcnow()}}); return public(col.find_one({"_id":d["_id"]}))
def list_assets(uid,kind):
 col=r.media if kind=="media" else r.documents; return [public(x) for x in col.find({"user_id":uid}).sort("created_at",-1).limit(200)]
def get_asset(uid,kind,pid):
 col=r.media if kind=="media" else r.documents; d=_get(col,pid,uid)
 if not d:raise DomainError(404,"NOT_FOUND","Asset not found")
 return public(d)
def delete_asset(uid,kind,pid):
 col=r.media if kind=="media" else r.documents; d=_get(col,pid,uid)
 if not d:raise DomainError(404,"NOT_FOUND","Asset not found")
 col.delete_one({"_id":d["_id"]}); return True
def create_verification(uid,data):
 open_req=r.verification_requests.find_one({"user_id":uid,"domain":data.domain,"status":{"$in":["pending","in_review","needs_info"]}})
 if open_req:raise DomainError(409,"OPEN_REQUEST_EXISTS","An open request already exists for this domain")
 d=data.model_dump(); d.update(public_id=str(uuid4()),user_id=uid,status="pending",history=[{"status":"pending","at":r.utcnow()}],created_at=r.utcnow(),updated_at=r.utcnow()); r.verification_requests.insert_one(d); return public(d)
def list_verification(uid):return [public(x) for x in r.verification_requests.find({"user_id":uid}).sort("created_at",-1).limit(100)]
def get_verification(uid,pid):
 d=_get(r.verification_requests,pid,uid)
 if not d:raise DomainError(404,"NOT_FOUND","Verification request not found")
 return public(d)
def resubmit(uid,pid,note=None):
 d=_get(r.verification_requests,pid,uid)
 if not d:raise DomainError(404,"NOT_FOUND","Verification request not found")
 if d["status"] not in ("needs_info","rejected"):raise DomainError(409,"INVALID_STATE","Only needs_info or rejected requests can be resubmitted")
 hist=d.get("history",[])+[{"status":"pending","at":r.utcnow(),"note":note}]
 r.verification_requests.update_one({"_id":d["_id"]},{"$set":{"status":"pending","history":hist,"updated_at":r.utcnow()}}); return public(r.verification_requests.find_one({"_id":d["_id"]}))
def decide_verification(pid,reviewer_id,data):
 d=_get(r.verification_requests,pid)
 if not d:raise DomainError(404,"NOT_FOUND","Verification request not found")
 if d["status"] not in ("pending","in_review","needs_info"):raise DomainError(409,"INVALID_STATE","Request is not reviewable")
 now=r.utcnow(); hist=d.get("history",[])+[{"status":data.decision,"at":now,"reviewer_id":reviewer_id,"reason":data.reason}]
 r.verification_requests.update_one({"_id":d["_id"]},{"$set":{"status":data.decision,"decision_reason":data.reason,"reviewer_id":reviewer_id,"history":hist,"updated_at":now}})
 if d["domain"]=="performance" and d.get("target_id"):
  p=_get(r.performance_entries,d["target_id"],d["user_id"])
  if p:
   r.performance_entries.update_one({"_id":p["_id"]},{"$set":{"verification_status":"verified" if data.decision=="verified" else data.decision,"updated_at":now}}); rebuild_metric_best(d["user_id"],p["sport_id"],p["metric_key"])
 return public(r.verification_requests.find_one({"_id":d["_id"]}))
