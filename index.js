const express = require("express");
const { PubSub } = require("@google-cloud/pubsub");

const app = express();

const PORT = process.env.PORT || 8080;
const PUBSUB_TOPIC = process.env.PUBSUB_TOPIC || "orders-created";

const pubSubClient = new PubSub();

app.use(express.json());


// Health check
app.get("/health", (req, res) => {
    res.status(200).json({
        status: "healthy",
        service: "order-api"
    });
});


// Create order
app.post("/orders", async (req, res) => {
    try {
        const { customer, items, total } = req.body;

        if (!customer) {
            return res.status(400).json({
                error: "Customer is required"
            });
        }

        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({
                error: "At least one item is required"
            });
        }

        if (total === undefined || total === null) {
            return res.status(400).json({
                error: "Total is required"
            });
        }

        const order = {
            orderId: `order-${Date.now()}`,
            customer,
            items,
            total,
            status: "accepted",
            createdAt: new Date().toISOString()
        };

        const messageBuffer = Buffer.from(
            JSON.stringify(order)
        );

        const messageId = await pubSubClient
            .topic(PUBSUB_TOPIC)
            .publishMessage({
                data: messageBuffer
            });

        console.log("Order created:", order);
        console.log("Pub/Sub message ID:", messageId);

        res.status(201).json({
            ...order,
            messageId
        });

    } catch (error) {

        console.error("Failed to create order:", error);

        res.status(500).json({
            error: "Failed to create order"
        });
    }
});


app.listen(PORT, () => {
    console.log(`Order API listening on port ${PORT}`);
});