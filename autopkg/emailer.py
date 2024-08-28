#!/usr/bin/env python3

import smtplib
from email.message import EmailMessage
from sys import argv
import pathlib

TO_ADDR = argv[1]
FROM_ADDR = argv[2]
SUBJECT = 'autopkg log'
RELAY_ADDR = 'relay.example.com'

AUTOPKG_LOG = pathlib.Path('/private/tmp/autopkg.out')

def main():
    if not AUTOPKG_LOG.exists():
        raise Exception(f"Missing {AUTOPKG_LOG}")
    with open(AUTOPKG_LOG, 'r', encoding='utf-8') as fh:
        log = fh.read()
    msg = EmailMessage()
    msg.set_content(log)
    msg['Subject'] = SUBJECT
    msg['From'] = FROM_ADDR
    msg['To'] = TO_ADDR
    with smtplib.SMTP(RELAY_ADDR, 25) as s:
        s.send_message(msg)

if __name__ == '__main__':
    main()
