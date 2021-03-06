'use strict'

Q           = require 'q'
mongoose    = require 'mongoose'
nodemailer  = require 'nodemailer'
uuid        = require 'node-uuid'

UserSchema = new mongoose.Schema(

  username:
    type: String
    unique: true
    required: true

  email:
    type: String
    unique: true
    required: true

  # Should make seperate schema for token here and associate it with the user
  # this will allow us to have an expiring reset token for
  pass_reset:
    type: String

  password:
    type: String
    required: true

  salt: String

  createdAt:
    type: Date
    default: Date.now

  updatedAt:
    type: Date
    default: Date.now

  pro: Boolean

  groups:
    [{type: mongoose.Schema.ObjectId, ref: 'Group'}]

  authData:

    fitbit:
      avatar: String
      access_token: String
      access_token_secret: String
)

###
Static methods to increase flow and tedious queries
###

# Find user by email, mainly used in password reset but not soley
UserSchema.statics.findByEmail = (email) ->
  defer = Q.defer()
  @findOne 'email': email, (err, user) ->
    if err then defer.reject err
    if user then defer.resolve user
    # FIXME
    if not user then console.log 'no user by that email'
  defer.promise

UserSchema.statics.resetPassword = (user) ->
  User = mongoose.model 'User'
  defer = Q.defer()
  # get set up the given user's _id to search
  id = user._id

  # define what fields will be updated and with what values
  update =
    pass_reset: uuid.v4() # genrates a v4 random uuid

  # define options on the query, this one will return the reset
  # token that was just updated
  options =
    select:
      'pass_reset': true

  console.log 'id', id, 'update', update, 'options', options

  User.findByIdAndUpdate id, update, options, (err, reset_token) ->
    if err then defer.reject err
    if reset_token
      userAndEmail =
        email: user.email
        reset: reset_token
        username: user.username

      defer.resolve userAndEmail
    if not reset_token then console.log 'could not get reset_token'
  defer.promise

UserSchema.statics.emailPassword = (user) ->
  # create a reusable transport method with nodemailer
  defer = Q.defer()
  smtpTransport = nodemailer.createTransport(
    'SMTP', {service: 'Gmail', auth: {
      user: 'willscottmoss@gmail.com'
      pass: 'ballin35'
      }
    }
  )

  console.log 'reset', user.reset.pass_reset
  # setup email options to be sent can HTML if need be, All Unicode
  mailOptions =
    'from': 'Scott Moss <scottmoss35@gmail.com>'
    'to': user.email
    'subject': 'Sweatr reset password'
    'html': "<h1> Hello #{user.username}!</h1>"+
            "<p> Here is the link to reset your password </p>" +
            "<a href=http://localhost:3000/user/reset/"+
            "#{user.reset.pass_reset} >Reset</a>"

  smtpTransport.sendMail mailOptions, (err, response) ->
    if err then defer.reject err
    if response then defer.resolve response

  defer.promise

module.exports = mongoose.model 'User', UserSchema