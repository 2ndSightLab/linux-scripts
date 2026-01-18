# Minimal Python "converter" if ykman is missing
# to convert code to AWS TOTP code 
#(untested and may leave secrets in memory - just exploring optiosn)
import time
from ykman.device import list_all_devices
from ykman.oath import OathSession

def get_code(name):
    device, info = list_all_devices()[0]
    session = OathSession(device.open_connection(OathSession))
    # This sends the current time to the key
    cred = next(c for c in session.list_credentials() if name in c.name)
    return session.calculate_code(cred).value

print(get_code("AWS:your-account"))

