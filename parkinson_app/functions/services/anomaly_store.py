"""Per-user anomaly-model artifact store (Stage 5.3 / 6.4).

The Isolation Forest is serialized to Cloud Storage at
`anomaly_models/{userId}/isolation_forest.joblib`; Firestore keeps only
the path/metadata. `reset_baseline` deletes the artifact before a fresh
baseline is built. Requires Cloud credentials — wired at deploy time.
"""

ARTIFACT_PATH_TEMPLATE = "anomaly_models/{user_id}/isolation_forest.joblib"
MOTOR_ARTIFACT_PATH_TEMPLATE = \
    "anomaly_models/{user_id}/isolation_forest_motor.joblib"


def artifact_path(user_id: str, kind: str = "typing") -> str:
    if kind == "motor":
        return MOTOR_ARTIFACT_PATH_TEMPLATE.format(user_id=user_id)
    return ARTIFACT_PATH_TEMPLATE.format(user_id=user_id)


def save_user_anomaly_model(user_id: str, model,  # noqa: ANN001
                            kind: str = "typing") -> str:
    """Persist a fitted model; returns the storage path for Firestore."""
    from google.cloud import storage  # deferred: needs Cloud credentials

    client = storage.Client()
    bucket = client.bucket(_bucket_name())
    blob = bucket.blob(artifact_path(user_id, kind))
    blob.upload_from_string(_serialize(model))
    return artifact_path(user_id, kind)


def load_user_anomaly_model(user_id: str, kind: str = "typing"):
    from google.cloud import storage  # deferred: needs Cloud credentials

    client = storage.Client()
    bucket = client.bucket(_bucket_name())
    blob = bucket.blob(artifact_path(user_id, kind))
    if not blob.exists():
        return None
    return _deserialize(blob.download_as_bytes())


def delete_user_anomaly_model(user_id: str) -> None:
    from google.cloud import storage  # deferred: needs Cloud credentials

    client = storage.Client()
    bucket = client.bucket(_bucket_name())
    for kind in ("typing", "motor"):
        blob = bucket.blob(artifact_path(user_id, kind))
        if blob.exists():
            blob.delete()


def _bucket_name() -> str:  # TODO(Stage 6 deploy): bind to project bucket
    raise NotImplementedError("Cloud Storage bucket binding lands at deploy.")


def _serialize(model) -> bytes:  # noqa: ANN001
    import joblib

    import io

    buffer = io.BytesIO()
    joblib.dump(model, buffer)
    return buffer.getvalue()


def _deserialize(payload: bytes):
    import joblib

    import io

    return joblib.load(io.BytesIO(payload))
