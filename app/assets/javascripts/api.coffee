var api = new function(){

    this.utilities = function(callback){
        $.ajax({
            url: getURL()+'/personal_research_assistant/utilities',
            method: 'GET',
            success: function(data){
                callback(data);
            }
        });
    };

//    this.utility = function(id,callback){
//        $.ajax({
//            url: getURL()+'/personal_research_assistant/utilities',
//            method: 'GET',
//            data: {'id':id},
//            success: function(data){
//                callback(data);
//            }
//        });
//    };

    // private

    var getURL = function(){
        return window.location.protocol+"//"+window.location.host
    };


}