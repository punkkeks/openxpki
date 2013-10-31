/** format helper: factory & base classes */

/**
you can dynamically register new Helper via OXI.FormatHelperFactory.registerComponent(format,componentname,method)
*/

"use strict";

OXI.FormatHelperFactory = OXI.ComponentFactory.create({
    _componentMap : {
        timestamp :  'FormatTimestamp',
        link      :  'FormatLink',
        
        _lastItem: '' //avoid trailing commas
    },

    _instances: {},

    /** direct access to singleton-helper */
    getHelper: function (type){
        if(!this._instances[type]){
            this._instances[type] = this.getComponent(type,{});//no params possible here
        }
        return this._instances[type];
    },
    
    _lastItem: '' //avoid trailing commas
});


OXI.FormatHelper = Ember.Object.extend({
    format: function(data){
        return data;
    },
    
    _lastItem: '' //avoid trailing commas
});

OXI.FormatTimestamp = OXI.FormatHelper.extend({
    format: function(timestamp){
        var D = new Date(parseInt(timestamp)*1000);
        //return D.toLocaleString();
        return D.toGMTString();
    },
    
    _lastItem: '' //avoid trailing commas
});

OXI.FormatLink  = OXI.FormatHelper.extend({
    format: function(link){

        if(!link.label){
            App.applicationAlert('link with no label!');
            return;
        }
        if(!link.page && !link.action){
            App.applicationAlert('link '+label+'with neither action nor page!');
            return;
        }
        if(!link.target){
            link.target='main';   
        }
        var link_id = OXI.getUniqueId();
        
        OXI.registerMethod(link_id,function(){
                App.handleAction(link);
            });
        
        var $link;
        //if(link.target=='main' && !link.action){
        //   $link = $('<a/>').html(link.label).attr('href','#/'+link.page);
        //}else{
            $link = $('<a/>').html(link.label).attr('id',link_id).attr('href','#').attr('onclick',"OXI.callMethod('"+link_id+"');event.cancelBubble=true;return false;");
        //}
        var $outer =   $('<div/>');   
        $link.appendTo($outer);                
        return $outer.html();

    },
    
    _lastItem: '' //avoid trailing commas
});

