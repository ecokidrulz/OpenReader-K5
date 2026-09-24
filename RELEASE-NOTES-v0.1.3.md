# OpenReader-K5 v0.1.3

Small runtime hotfix for Kindle Touch / K5 firmware 5.3.7.3.

## Fix

Corrected the startup path to the K5 EPDC framebuffer recovery helper.

v0.1.2 referenced:

/mnt/us/extensions/openReader/epdc-resume.sh

The helper is actually installed at:

/mnt/us/extensions/openReader/bin/epdc-resume.sh

This restores the intended defensive EPDC pause-state recovery during OpenReader startup.

No other runtime behavior is intentionally changed from v0.1.2.
