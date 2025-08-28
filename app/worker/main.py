import os, json, sys

def main():
    event = os.environ.get("CS_EVENT_JSON", "{}")
    print("Lara review-worker started.")
    print("EVENT:", event)
    return 0

if __name__ == "__main__":
    sys.exit(main())