$(document).ready(function(){
    $(".login-credentials").bind("focusin", function() {
      if ($(this).hasClass("initial")) {
        $(this).removeClass("initial");
        $(this).val("");
      }
    });

    $(".login-credentials").bind("focusout", function() {
      if ($(this).val() == "") {
        $(this).addClass("initial");
        $(this).val($(this).attr("data-stdtext"));
      }
    });

    $("#submit").bind("click", function() {
      $("#loginform").submit();
    });

    $(".login-credentials").bind("keypress", function(e) {
      code = (e.keyCode ? e.keyCode : e.which);
      if (code == 13) {
        $("#loginform").submit();
      }
    });

    $("#loginform").bind("submit", function() {
      button = $("#submit");
      // No mutiple submit.
      if (button.hasClass("submit-disabled")) {
        return false;
      }

      button.html("Loading...");
      button.addClass("submit-disabled");

      $(this).submit();
    });
});
