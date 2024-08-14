#!/usr/bin/env python3

import smtplib
from email.message import EmailMessage
from sys import argv

# TODO: generalize
TO_ADDR = argv[0]
FROM_ADDR = argv[1]
SUBJECT = 'autopkg log'
RELAY_ADDR = 'relay.example.com'

AUTOPKG_LOG = '/private/tmp/autopkg.out'

def main():
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
