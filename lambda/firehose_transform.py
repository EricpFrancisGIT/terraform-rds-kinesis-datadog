import base64, gzip, io, json, os

def _decode_cwl(record_data_b64: str):
    raw = base64.b64decode(record_data_b64)
    with gzip.GzipFile(fileobj=io.BytesIO(raw)) as gz:
        return json.loads(gz.read().decode("utf-8"))

def handler(event, context):
    out_records = []
    dd_source  = os.environ.get("DD_SOURCE", "rds-postgres")
    dd_service = os.environ.get("DD_SERVICE", "rds")

    for rec in event.get("records", []):
        try:
            cwl = _decode_cwl(rec["data"])
            lg  = cwl.get("logGroup")
            ls  = cwl.get("logStream")
            lines = []
            for le in cwl.get("logEvents", []):
                lines.append({
                    "message": le.get("message", ""),
                    "ddsource": dd_source,
                    "service": dd_service,
                    "ddtags": f"log_group:{lg},log_stream:{ls}",
                    "timestamp": le.get("timestamp")  # ms epoch
                })
            payload = "\n".join(json.dumps(l) for l in lines).encode("utf-8")
            out_records.append({
                "recordId": rec["recordId"],
                "result": "Ok",
                "data": base64.b64encode(payload).decode("utf-8")
            })
        except Exception:
            out_records.append({
                "recordId": rec["recordId"],
                "result": "ProcessingFailed",
                "data": rec["data"]
            })
    return {"records": out_records}
