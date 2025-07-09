const crypto = require('crypto');

const payload = JSON.stringify({
  "action": "created",
  "issue": {
    "number": 15,
    "html_url": "https://github.com/dblitz-com/gengine/issues/15"
  },
  "comment": {
    "body": "@claude create a hello world file in TypeScript",
    "user": {
      "login": "dBlitz",
      "type": "User"
    }
  },
  "repository": {
    "name": "gengine",
    "owner": {
      "login": "dblitz-com"
    },
    "full_name": "dblitz-com/gengine"
  }
});

const secret = 'c9e63328381309a2293f948cd68fab94d81227bdeaff5fd57d0a1febdd587328';
const signature = 'sha256=' + crypto.createHmac('sha256', secret).update(payload).digest('hex');

console.log('Payload:', payload);
console.log('Signature:', signature);
