const express = require("express");
const router = express.Router();

const {
  register,
  login,
  // add other functions if you use them in this file
} = require("../controllers/userController"); // or 'authController'

router.post("/register", register);
router.post("/login", login);
// add other routes as needed

module.exports = router;
