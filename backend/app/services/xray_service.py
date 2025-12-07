import json
from pathlib import Path
import os
from sqlalchemy.orm import Session
from app.crud import config
# from app.models.config import Config


class XrayService:
    def __init__(self, db: Session, template_path: str, output_path: str, service_name: str, base_port: int,
                 enable_service: bool = True):

        self.db = db
        cwd = Path(os.getcwd())
        self.template_path = Path(template_path)
        if not self.template_path.is_absolute():
            self.template_path = cwd / self.template_path
        self.output_path = Path(output_path)
        if not self.output_path.is_absolute():
            self.output_path = cwd / self.output_path
        self.output_path.mkdir(parents=True, exist_ok=True)
        self.output_file = self.output_path / "config.json"
        self.service_name = service_name
        self.base_port = base_port
        self.enable_service = enable_service
        self.config = config

    def _save_xray_config_to_file(self, config: dict):
        with open(self.output_file, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=2)

    def sync_config(self, config_obj: dict | None = None):
        try:
            with open(self.template_path, "r", encoding="utf-8") as f:
                xray_config = json.load(f)

            if config_obj:
                xray_config.update(config_obj)

            self._save_xray_config_to_file(xray_config)
            return {"status": "success", "message": "Xray config synced successfully."}

        except FileNotFoundError:
            return {"status": "error", "message": f"Xray config template not found at {self.template_path}"}
        except json.JSONDecodeError:
            return {"status": "error", "message": f"Invalid JSON in template file {self.template_path}"}
        except Exception as e:
            return {"status": "error", "message": f"An unexpected error occurred: {str(e)}"}

    def sync_database_to_xray(self):
        print("========== XRAY DEBUG START ==========")

        try:
            # 1) دیتابیس را لود کن
            print("[XRAY DEBUG] Loading configs from DB...")
            configs = self.config.get_multi(self.db)
            print(f"[XRAY DEBUG] Found {len(configs)} configs in database")

            results = []

            for config_obj in configs:
                print("--------------------------------------")
                print(f"[XRAY DEBUG] Processing config id={config_obj.id}")

                try:
                    # تبدیل ORM به dict
                    config_dict = {
                        "id": config_obj.id,
                        "name": config_obj.name,
                        "user_id": config_obj.user_id,
                        "server_id": config_obj.server_id,
                        "protocol": config_obj.protocol,
                        "config_data": config_obj.config_data,
                        "traffic_limit_gb": config_obj.traffic_limit_gb,
                        "traffic_used_gb": config_obj.traffic_used_gb,
                        "expiry_date": str(config_obj.expiry_date),
                        "is_active": config_obj.is_active,
                    }

                    print("[XRAY DEBUG] Converted model to dict OK")

                    # اجرای sync_config
                    print("[XRAY DEBUG] Calling sync_config() ...")
                    sync_result = self.sync_config(config_dict)
                    print("[XRAY DEBUG] sync_config() OK, result:", sync_result)

                    results.append({
                        "config_id": config_obj.id,
                        "success": True,
                        "result": sync_result
                    })

                except Exception as e:
                    print("[XRAY ERROR] Error while processing config", config_obj.id)
                    print("[XRAY ERROR] Exception:", e)
                    results.append({
                        "config_id": config_obj.id,
                        "success": False,
                        "error": str(e)
                    })

            print("========== XRAY DEBUG END ==========")
            return {
                "status": "success",
                "message": "Xray configurations synchronized.",
                "details": results
            }

        except Exception as e:
            print("========== XRAY CRITICAL ERROR ==========")
            print("[XRAY CRASH] Exception in sync_database_to_xray:", e)
            raise e

