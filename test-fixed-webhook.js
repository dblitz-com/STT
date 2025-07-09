const crypto = require('crypto');

const payload = JSON.stringify({
  "action": "created",
  "issue": {
    "number": 15,
    "title": "Test Issue",
    "html_url": "https://github.com/dblitz-com/gengine/issues/15",
    "user": {
      "login": "dBlitz",
      "type": "User"
    },
    "state": "open"
  },
  "comment": {
    "body": "@claude create a hello world TypeScript file",
    "user": {
      "login": "dBlitz",
      "type": "User"
    },
    "html_url": "https://github.com/dblitz-com/gengine/issues/15#issuecomment-123456"
  },
  "repository": {
    "name": "gengine",
    "owner": {
      "login": "dblitz-com"
    },
    "full_name": "dblitz-com/gengine",
    "clone_url": "https://github.com/dblitz-com/gengine.git",
    "default_branch": "main"
  },
  "sender": {
    "login": "dBlitz",
    "type": "User"
  }
});

const secret = 'c9e63328381309a2293f948cd68fab94d81227bdeaff5fd57d0a1febdd587328';
const signature = 'sha256=' + crypto.createHmac('sha256', secret).update(payload).digest('hex');

console.log('Signature:', signature);
