from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    db_url = os.environ.get('DATABASE_URL', 'No DB URL set')
    return f'<h1>Hello from your Flask App on ECS!</h1><p>Database URL configured: {db_url}</p>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
