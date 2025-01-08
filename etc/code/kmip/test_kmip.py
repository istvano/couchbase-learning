# test_kmip.py
import ssl

from kmip.pie import objects
from kmip.pie import client
from kmip import enums
from kmip.core.attributes import CryptographicAlgorithm, CryptographicLength

import base64
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes

import os
import logging

# Configure logging to show debug messages
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# KMIP server configuration - replace with your values or use environment variables
kmip_host = os.getenv('KMIP_HOST', 'https://localhost')
kmip_port = int(os.getenv('KMIP_PORT', '9998'))
kmip_cert = os.getenv('KMIP_CERT', '/certs/client_certificate.pem')
kmip_key = os.getenv('KMIP_KEY', '/certs/client_key.pem')
kmip_ca = os.getenv('KMIP_CA', '/certs/ca_certificate.pem')

# Establish a KMIP client connection and create/retrieve a key
def test_kmip_key_creation_and_retrieval():
    # Create a client instance
    kmip_client = client.ProxyKmipClient(
        hostname=kmip_host,
        port=kmip_port,
        cert=kmip_cert,
        key=kmip_key,
        ca=kmip_ca,
        config='client',
        config_file='/etc/pykmip/pykmip.conf',
        kmip_version=enums.KMIPVersion.KMIP_1_2,
    )

    try:
        # Open the client connection
        kmip_client.open()

        print(f"Connection opened")

        # Step 1: Create a symmetric key (AES) on the KMIP server
        key_id = kmip_client.create(
            algorithm=enums.CryptographicAlgorithm.AES,
            length=256  # Key size in bits
        )
        print(f"Symmetric key created with ID: {key_id}")

        # Step 2: Retrieve the key
        retrieved_key = kmip_client.get(key_id)
        print(f"Retrieved key: {retrieved_key}")

        # Close the client connection
        kmip_client.close()

        # Convert the retrieved key into a usable form
        key_bytes = base64.b64encode(retrieved_key.value).decode('utf-8')
        print(f"Key bytes: {key_bytes}")

        # Step 3: Use the retrieved key to encrypt some data
        plaintext = b'This is a test message'
        iv = get_random_bytes(16)  # AES requires a 16-byte IV
        print(f"Iv generated: {iv}")

        cipher = AES.new(retrieved_key.value, AES.MODE_CBC, iv)
        ciphertext = iv + cipher.encrypt(plaintext.ljust(32))  # Padding to 32 bytes

        print(f"Encrypted data: {base64.b64encode(ciphertext).decode()}")

        return True

    except Exception as e:
        print(f"An error occurred: {e}")
        return False

    finally:
        # Ensure the client is closed properly
        kmip_client.close()

# Run the test
if __name__ == "__main__":
    if test_kmip_key_creation_and_retrieval():
        print("Test completed successfully.")
    else:
        print("Test failed.")
