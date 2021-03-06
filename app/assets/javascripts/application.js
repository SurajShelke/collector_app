// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//= require turbolinks
//= require jquery3
//= require popper
//= require bootstrap
//= require_tree .
$(document).ready(function() {
  if ($("input:checkbox")){
    $("input:checkbox").change(function(){
      if($( "input:checked" ).length > 0)
        $('[name="btn_submit_folders"]').prop('disabled', false);
      else
        $('[name="btn_submit_folders"]').prop('disabled', true);
    });
  }
  if($("[name='root_id']")[0]){
    $('[name="folders['+ $('[name="root_id"]')[0].value +']"]').change(function(){ 
      $("input:checkbox").prop('disabled', this.checked); 
        this.disabled = false; 
    });
  }
});
