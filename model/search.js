/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

var mongoose = require('mongoose');



var searchSchema = mongoose.Schema({
    userId:{type:String, unique:true},
    query:Object
});

var FunctionCreatePlugin = require('../bin/plugin/fn-create-plugin').NoAuth;
searchSchema.plugin(FunctionCreatePlugin);

var Search = mongoose.model("Search", searchSchema);


module.exports = Search;


