import json
import boto3
import os
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ['TABLE_NAME']
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    http_method = event['requestContext']['http']['method']
    
    if http_method == 'POST':
        body = json.loads(event.get('body', '{}'))
        partner_id = body.get('partner_id', 'default_couple')
        timestamp = body.get('timestamp')
        message = body.get('message')
        
        table.put_item(Item={
            'partner_id': partner_id,
            'timestamp': timestamp,
            'message': message
        })
        return {'statusCode': 200, 'body': json.dumps({'status': 'Message secured!'})}
        
    elif http_method == 'GET':
        partner_id = event['queryStringParameters'].get('partner_id', 'default_couple') if event.get('queryStringParameters') else 'default_couple'
        response = table.query(
            KeyConditionExpression=Key('partner_id').eq(partner_id),
            ScanIndexForward=False,
            Limit=10
        )
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(response.get('Items', []))
        }
        
    return {'statusCode': 400, 'body': json.dumps('Unsupported method')}