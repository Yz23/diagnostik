from diagnostik_common.logging import configure_logging, get_logger


def main() -> None:
    configure_logging(service="diagnostik-worker")
    get_logger(__name__).info("worker_ready", extra={"event_type": "worker_ready", "status": "ready"})


if __name__ == "__main__":
    main()
