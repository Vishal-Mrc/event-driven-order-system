const express = require("express");
const { Firestore } = require("@google-cloud/firestore");

const app = express();
const db = new Firestore();

const PORT = process.env.PORT || 8080;
const ordersCollection = db.collection("orders");

app.use(express.json());

app.get("/health", (req, res) => {
    res.status(200).json({
        status: "healthy",
        service: "order-processor"
    });
});

app.post("/pubsub", async (req, res) => {
    try {
        const message = req.body.message;

        if (!message || !message.data) {
            console.error("Invalid Pub/Sub message");

            return res.status(400).json({
                error: "Invalid Pub/Sub message"
            });
        }

        const decodedData = Buffer
            .from(message.data, "base64")
            .toString("utf8");

        const order = JSON.parse(decodedData);

        

        console.log("Received order:", order);

        await ordersCollection
            .doc(order.orderId)
            .set({
                ...order,
                processedAt: new Date().toISOString(),
                processingStatus: "processed"
            });

        console.log(
            `Order ${order.orderId} saved to Firestore`
        );

        res.status(204).send();

    } catch (error) {

        console.error("Processing failed:", error);

        res.status(500).json({
            error: "Order processing failed"
        });
    }
});

app.listen(PORT, () => {
    console.log(
        `Order Processor listening on port ${PORT}`
    );
});