/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
var mongoose = require('mongoose');

mongoose.Promise = require('bluebird');
//var ElasticPlugin = require("mongoosastic");
var PiperPlugin = require("./plugin/piper-plugin");
var FakerPlugin = require('mongoose-easy-types').Plugin;
//var PaginationPlugin = require('mongoose-paginate');
var FindByUserIdPlugin = require('./plugin/fn-find-by-user-id-plugin');
//var FunctionCreatePlugin = require('./plugin/fn-create-plugin');


//var LogPlugin = require('./plugin/log-plugin');
//var NotificationPlugin = require('./plugin/notification-plugin');








//mongoose.plugin(FunctionCreatePlugin);
mongoose.plugin(FakerPlugin);
mongoose.plugin(PiperPlugin);
//mongoose.plugin(ElasticPlugin);
mongoose.plugin(FindByUserIdPlugin);

//mongoose.plugin(LogPlugin);
//mongoose.plugin(NotificationPlugin);






exports.startSocketCommunication = function (io){
    models = mongoose.models;
    for(var key in models){
        models[key].startSocketListener(io);
    }
};





exports.connect = function(database){

    mongoose.connect(database);
    var db = mongoose.connection;
    db.on('error', console.error.bind(console, 'connection error:'));
    db.once('open', function(err, response){
        console.log("connection to mongoose successful!");
        
        
    });
};





