"""App configuration. Server-side secrets stay server-side (spec 33):
browser code receives only public/client-safe values. Service-role keys
must NEVER be exposed; the API uses them only here if configured."""

import os


class Settings:
    supabase_url: str = os.environ.get("SUPABASE_URL", "")
    supabase_service_key: str = os.environ.get("SUPABASE_SERVICE_KEY", "")
    rf_artifact: str = os.environ.get("PARKINTRACE_RF_ARTIFACT", "")
    app_env: str = os.environ.get("APP_ENV", "dev")


settings = Settings()
