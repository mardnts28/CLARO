voiceIntent({ transcript: "take me to my history", language: "en" }, { auth: { uid: "test-user-123" } })
  .then(result => { console.log("RESULT1:" + JSON.stringify(result)); return voiceIntent({ transcript: "what is 2 plus 2", language: "en" }, { auth: { uid: "test-user-123" } }); })
  .then(result => { console.log("RESULT2:" + JSON.stringify(result)); process.exit(0); })
  .catch(err => { console.error("ERROR:" + (err.stack || err)); process.exit(1); });