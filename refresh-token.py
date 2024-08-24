from google_auth_oauthlib.flow import InstalledAppFlow

# Define the required scopes
SCOPES = ['https://www.googleapis.com/auth/youtube.upload']
CLIENT_SECRETS_FILE = 'client-secret.json'
TOKEN_FILE = 'token.json'


def authenticate():
    flow = InstalledAppFlow.from_client_secrets_file(
        CLIENT_SECRETS_FILE,
        SCOPES
    )
    credentials = flow.run_local_server(port=0)

    # Save the credentials for the next run

    with open(TOKEN_FILE, 'w') as token:
        token.write(credentials.to_json())


if __name__ == "__main__":
    youtube = authenticate()
