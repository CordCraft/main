/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

var express = require('express');
var authApp = express();
var jwt = require('jsonwebtoken');
var secrets = require('./config/jwt-secret');

var passport = require('passport');
var LocalStrategy = require('passport-local');
var TokenStrategy = require('passport-token-auth');
var FacebookStrategy = require('passport-facebook');
var GoogleStrategy = require('passport-google');
var LinkedinStrategy = require('passport-linkedin');
var TwitterStrategy = require('passport-twitter');
var InstagramStrategy = require('passport-instagram');


var User = require('./model/user');
var AccessToken = require('./model/accessToken');
var Developer = require('./model/developer');
var Admin = require('./model/admin');


var access = require('./config/accessType');



passport.use('local', new LocalStrategy({passReqToCallback:true}, login));

/*
passport.use(new FacebookStrategy(function(var1, var2, done){
    done(null, true);
}));


passport.use(new GoogleStrategy(function(var1, var2, done){
    done(null, true);
}));


passport.use(new LinkedinStrategy(function(var1, var2, done){
    done(null, true);
}));


passport.use(new TwitterStrategy(function(var1, var2, done){
    done(null, true);
}));


passport.use(new InstagramStrategy(function(var1, var2, done){
    done(null, true);
}));*/

authApp.use(passport.initialize());



authApp.set('validateAppCredentials', validateAppCredentials);
authApp.set('validateUserCredentials', validateUserCredentials);
authApp.set('validateAllCredentials', validateAppCredentials, validateUserCredentials);



authApp.get('/', getHere);
authApp.post('/devSignup', signupDeveloper);
authApp.post('/login', passport.authenticate('local', {session:false}),respond);
authApp.get('/logout', logout);



/*
authApp.post('/facebook', passport.authenticate('facebook', {session:false}),
    serialize, generateToken, respond
);


authApp.post('/twitter', passport.authenticate('twitter', {session:false}),
    serialize, generateToken, respond
);


authApp.post('/google', passport.authenticate('google', {session:false}),
    serialize, generateToken, respond
);


authApp.post('/linkedin', passport.authenticate('linkedin', {session:false}),
    serialize, generateToken, respond
);


authApp.post('/instagram', passport.authenticate('instagram', {session:false}),
    serialize, generateToken, respond
);

*/






function getHere(req, res){
    res.json({
        action:"no action",
        status:"not authenticated"
    });
    return true;
}

function login(req, username, password, done){
    if(username && password){
        User.findOne({'local.username':username}, function(err, user){
            if(err) throw err;
            //If user doesn't exist in the database: Create new user.
            if(!user){
                error = {
                    action:"login",
                    status:"failed",
                    reason:"username does not exist"
                };
                req.error = error;
                return done(null, error);
            }
            //Otherwise, if user exist in the database: Login user.
            else{
                var passwordIsValid = user.local.password === password;
                
                //If password provided is not valid: Send error.
                if(!passwordIsValid){
                    error = {
                        action:"authentication",
                        status:"failed",
                        reason:"invalid password"
                    };
                    req.error = error;
                    return done(null, error);
                }
                
                //Otherwise, if password is valid: store user in request Object
                //And send user.
                else{
                    var response = {
                        action:'login',
                        data: user,
                        dataType:'user',
                        status:'success'
                    };
                    req.response = response;
                    return done(null, req.response);
                }
            }
        });
    }
};

function validateAppCredentials(req, res, next){
    var developer = {};
    developer.appKey = req.headers.app_key;
    developer.appSecret = req.headers.app_secret;
    if(!(developer.appKey && developer.appSecret)){
        var response = {
            action:'developer authentication',
            status:'failed',
            type:401,
            reason: 'appKey and/or appSecret cannot be empty'
        };
        res.status(401).json(response);
        return false;
    }
    else{
        Developer.findByKeyAndSecret(developer.appKey, developer.appSecret, 
        function(err, developer){
            if(err){
                var response = {
                    action: 'developer authentication',
                    status: 'failed',
                    type: 401,
                    reason: err
                };
                res.status(401).json(response);
                return false;
            }
            else if(!developer){
                var response = {
                    action: 'developer authentication',
                    status: 'failed',
                    type: 401,
                    reason: 'wrong appKey and/or appSecret'
                };
                res.status(401).json(response);
                return false;
            }
            else{
                req.developer = developer;
                return next();
            }
        });
    }
        
}

function validateUserCredentials(req, res){
    var accessToken = req.accessToken;
    if(!accessToken){
        var response = {
            action: 'user authentication',
            status: 'failed',
            type: 401,
            reason: 'access token cannot be empty. Provide accessToken or login'
        };
        res.status(401).json(response);
        return false;
    }
    AccessToken.findOne({token:accessToken}, function(err, token){
        if(err)return done(err);
        var userId = token.userId;
        if(!userId) return done(null, false);
        User.findById(userId, function(err, user){
            if(err){
                var response = {
                    action: 'user authentication',
                    status: 'failed',
                    type: 401,
                    reason: err
                };
                res.status(401).json(response);
                return false;
            }
            else if(!user){
                var response = {
                    action: 'user authentication',
                    status: 'failed',
                    type: 401,
                    reason: "wrong user credentials. Please try again with another"
                };
                res.status(401).json(response);
                return false;
            }
            else{
                req.user = user;
                return user;
            }
        });
    });
}

exports.validateJawadAccess = function(req, res){
    
};

exports.validateMeetAccess = function(req, res){
    
};

exports.validatePublicAccess = function(req, res){
  var userId = req.userId;
  if(!userId){
      
  }
  else{
      res.status(200).json(req.response);
  }
};


exports.validateEditorAccess = function(req, res){
    var dataUserId = req.response.data.userId;
    var userId = req.user._id;
    if(!(dataUserId === userId) || !userId){
        var response = {
            action: "access api",
            status: "failed",
            reason: "editor access only"
        };
        res.status(400).json(response);
        return false;
    }
    else{
        req.status(200).json(req.response);
    }
};


exports.validateAdminAccess = function(req, res){
    var userId = req.user._id;
    if(!userId) {
        var response = {
            action:'access api',
            status:"failed",
            reason:"admin access only"
        };
        res.status(400).json(response);
        return null;
    }
    return Admin.findOne({userId:userId}, function(err, admin){
        if(err){
            var response = {
                action: 'access api',
                status: "failed",
                reason: err
            };
            res.status(400).json(response);
            return null;
        }
        else if(!admin){
            var response = {
                action: 'access api',
                status: "failed",
                reason: "admin access only. Empty"
            };
            res.status(400).json(response);
            return null;
        }
        else{
            res.status(200).json(req.response);
            return req.response;
        }
    });
};


exports.validateProximityZeroAccess = function(req, res){
    
};

exports.validateProximtyFirstAccess = function(req, res){
    
};

exports.validateProximitySecondAccess = function(req, res){
    validateProximityZeroAccess(req, res);
    
    
};

exports.validateProximityThirdAccess = function(req, res){
    validateProximityFirstAccess(req, res);
    
    
};

exports.validateCustomAccess = function(req, res){
    
};

exports.validateAccess = function(req, res){   
    var accessType = req.accessType;
    switch(accessType){
        case access.JAWAD: validateJawadAccess(req, res); break;
        case access.ADMIN: validateAdminAccess(req, res); break;
        case access.EDITOR: validateEditorAccess(req, res); break;
        case access.DEVELOPER: validateDeveloperAccess(req,res); break;
        case access.NETWORK: validateNetworkAccss(req, res); break;
        case access.MEET: validateMeetAccess(req, res); break;
        case access.PROXIMITY_0: validateProximityZeroAccess(req, res); break;
        case access.PROXIMITY_1: validateProximityFirstAccess(req, res); break;
        case access.PROXIMITY_2: validateProximitySecondAccess(req, res); break;
        case access.PROXIMITY_3: validateProximityThirdAccess(req, res); break;
        case access.PUBLIC: validatePublicAccess(req, res); break;
        default: return function(){
            var response = {
                action:'document access',
                status:'failed',
                reason:'invalid access type'
            };
            res.status(401).json(response);
            return null;
        };
    }
};





var Network = require('./model/network');
var Admin = require('./model/admin');
var access = require('./config/accessType');
var jChecker = require('./config/jawad');
exports.classifyAccessor = function(userId, accessorId, callback){
    if(jChecker.checkIfJawad(accessorId)){
        var accessType = access.JAWAD;
        return callback(null, accessType);
    };
    Admin.findById(accessorId, function(err, admin){
        if(err) callback(err);
        else if(!admin) {
            return callback(null, false);
        }
        else{
            var accessType = access.ADMIN;
            return callback(null, accessType);
        }
    });
    if(userId === accessorId){
        var accessType = access.EDITOR;
        return callback(null, accessType);
    };
    var query = {bond:{$and:[userId, accessorId]}};
    Network.find(query, function(err, network){
        if(err) callback(err);
        else{
            if(network.shared){
                var accessType = access.SHARER;
                return callback(null, accessType);
            }
            else if(network.confirmed){
                var accessType = access.NETWORK;
                return callback(null, accessType);
            }
            else if(network.meet){
                var accessType = access.MEET;
                return callback(null, accessType);
            }
            else{
                var accessType = access.PUBLIC;
                return callback(null, accessType);
            }
        }
    });
};


function signupDeveloper(req, res){
    var developerInit = {};
    developerInit.appName = req.body.appName;
    developerInit.accessType = req.body.accessType;
    if(!(developerInit.appName && developerInit.accessType)){
        var response = {
            action:'developer signup',
            status:'failed',
            reason:"appName and/or accessType cannot be empty"
        };
        res.status(400).json(response);
    }
    else{
        var developer = new Developer(developerInit);
        developer.genAndSave(function(err, developer){
                if(err) {
                    var response = {
                        action:'developer signup',
                        status:'failed',
                        reason: err
                    };
                    res.status(400).json(response);
                }
                else if(!developer){
                    var response = {
                        action:'develooper signup',
                        status:'failed',
                        reason:'developer empty'
                    };
                    res.status(400).json(response);
                }
                else{
                    var response = {
                        action:'developer signup',
                        status:'success',
                        data: developer,
                        dataType: 'developer'
                    };
                    res.status(200).json(response);
                }
            }); 
    }
}

function logout (req, res){
    req.logout =true;
    var user = req.user;
    if(!user){
        res.json({
            action:"logout",
            status:"success"
        });
    }
    else{
        res.json({
            action:"logout",
            status:"failed",
            reason:""
        });
    }
}

function respond(req, res){
    if(req.error){
        var error = req.error;
        res.status(500).json(error);
    }
    else{
        var response = req.response;
        res.status(200).json(response);
    }
}



module.exports = authApp;