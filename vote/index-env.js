const nunjucks = require('nunjucks')
const express = require('express')
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb")
const { DynamoDBDocumentClient, ScanCommand, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb')
const { fromEnv, fromIni } = require('@aws-sdk/credential-providers')
const axios = require('axios')

const NODE_ENV = process.env.NODE_ENV || 'production'
const VERSION = process.env.VERSION || '1.0.0'
const WEBSITE_PORT = process.env.WEBSITE_PORT || 3000
const DYNAMO_TABLE = process.env.DYNAMO_TABLE || 'vote'
const DYNAMO_REGION = process.env.DYNAMO_REGION || 'eu-west-3'

console.log(`NODE_ENV: ${NODE_ENV} | process.env: ${process.env.NODE_ENV}`)
console.log(`VERSION: ${VERSION} | process.env: ${process.env.VERSION}`)
console.log(`DYNAMO_TABLE: ${DYNAMO_TABLE} | process.env: ${process.env.DYNAMO_TABLE}`)
console.log(`DYNAMO_REGION: ${DYNAMO_REGION} | process.env: ${process.env.DYNAMO_REGION}`)
console.log(`env.AWS_ACCESS_KEY_ID: ${process.env.AWS_ACCESS_KEY_ID}`)
console.log(`env.AWS_SECRET_ACCESS_KEY: ${process.env.AWS_SECRET_ACCESS_KEY}`)

const app = express()

app.use(express.static('public'))
app.use(express.json())

nunjucks.configure('views', {
    express: app,
    autoescape: false,
    noCache: true
})

app.set('view engine', 'njk')

app.locals.node_env = NODE_ENV
app.locals.version = VERSION

if (NODE_ENV == 'development') {
    const livereload = require('connect-livereload')
    app.use(livereload())
}

// https://github.com/aws/aws-sdk-js-v3/tree/main/packages/credential-providers#fromini
// https://github.com/aws/aws-sdk-js-v3/tree/main/packages/credential-providers#fromenv
// const credentials = NODE_ENV == 'development' ? fromIni() : fromEnv()

const credentials = fromEnv()
const client = new DynamoDBClient({ region:'eu-west-3', credentials })
const document = DynamoDBDocumentClient.from(client)

app.get('/', async (req, res) => {
    try {
        res.render('index')
        
    } catch (err) {
        return res.json({
            code: err.code, 
            message: err.message
        })
    }
})

/*
    curl http://localhost:3000/vote
*/
app.get('/vote', async (req, res) => {
   let up = await document.send(new GetCommand({
        TableName: DYNAMO_TABLE,
        Key: { 'name': 'up' }
    }))
    // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Optional_chaining
    // since node 14 : https://nodejs.org/en/blog/release/v14.0.0/
    up = up.Item?.value ?? 0

    let down = await document.send(new GetCommand({
        TableName: DYNAMO_TABLE,
        Key: { 'name': 'down' }
    }))
    down = down.Item?.value ?? 0
    return res.send({ up, down })
})

/*
    curl http://localhost:3000/vote \
        --header 'Content-Type: application/json' \
        --data '{"vote":"up"}'
*/
app.post('/vote', async (req, res) => {
    try {
        console.log('POST /vote: %j', req.body)

        let result = await document.send(new UpdateCommand({
            TableName: DYNAMO_TABLE,
            Key: { 'name': req.body.vote, },
            ExpressionAttributeNames: { '#v': 'value' },
            UpdateExpression: "ADD #v :nv",
            ExpressionAttributeValues: { ':nv': 1 },
            ReturnValues: 'ALL_NEW',
        }))

        return res.send({ success: true, result: 'hello' })
        
    } catch (err) {
        console.log('ERROR: POST /vote: %s', err.message || err.response || err);
        res.status(500).send({ success: false, reason: 'internal error' });
    }
})

app.listen(WEBSITE_PORT, () => {
    console.log(`listening on port ${WEBSITE_PORT}`)
})