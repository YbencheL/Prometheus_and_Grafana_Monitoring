const express = require('express');
const client = require('prom-client');

const port = 8000;

const app = express();

// creating a registry which registers the metrics
const register = new client.Registry();

// adding default metrics to the registry
client.collectDefaultMetrics({ register });

// custom metric - counter
const requestCounter = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'endpoint']
});

// custom metric - histogram
const requestHistogram = new client.Histogram({
    name: 'http_request_duration_seconds',
    help: 'HTTP request duration in seconds',
    labelNames: ['method', 'endpoint']
});

// registering requestCounter
register.registerMetric(requestCounter);

// registering requestHistogram
register.registerMetric(requestHistogram);

// Increment the counter on each request
app.use((req, res, next) => {
    const startTime = Date.now();
    res.on('finish', ( ) => {
        const duration = (Date.now() - startTime) / 1000;
        requestCounter.inc({
            method: req.method,
            endpoint: req.url
        });
        requestHistogram.labels(req.method, req.url)
        .observe(duration);
    });
    next();
});

// / route
app.get('/', (req, res) => {
    res.status(200).send("Here is your data!");
})

// expose /metrics endpoint for prometheus
app.get('/metrics', async (req, res) => {
    res.set('Content-type', register.contentType);
    res.end(await register.metrics());
});

app.listen(port, '0.0.0.0', () => {
    console.log(`HELLO, you are in port http://localhost:${port};)`);
})
