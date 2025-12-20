const express = require("express");
const { execFile } = require("child_process");
const path = require("path");
const app = express();

app.use(express.static(path.join(__dirname, "public")));

app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, "public", "webProxy.html"));
});

app.get("/fetch", (req, res) => {
    const url = req.query.url;
    if (!url) {
        return res.status(400).send("URL parameter is required");
    }
    execFile(path.join(__dirname, "fetch_page.sh"), [url], (error, stdout, stderr) => {
        if (error) {
            console.error(stderr);
            return res.send("Wget error");
        }
       const filepath = path.resolve(stdout.trim());
        res.sendFile(filepath);
    });
});


app.listen(3000, () => console.log("Server running on port 3000"));
