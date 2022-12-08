// Para mostrar y esconder las notas apartes:
$('.note .note-content').toggleClass('hide');

$('.note .aside-header').click(function(ev) {
    var noteContentElement = $(ev.target.parentElement.parentElement).find('.note-content');
    noteContentElement.toggleClass('hide');
});

$(document).ready(function(){
	$('.dark__mode>a').on("click" ,function(e){
		e.preventDefault();
		if ($("body").hasClass("dark")) {
			$("body").removeClass("dark");
			$(this).find("img").attr("src" ,"/images/moon.png");
		} else {
			$("body").addClass("dark");
			$(this).find("img").attr("src" ,"/images/sun.png");
		}
	});

	$(".menu__mobile>a").on("click" ,function(e){
		e.preventDefault();
		$('.bottom__header > nav').css("top" ,"0px");
		$('body,html').css("overflow-y" ,"hidden");
	});
	$('.close__menu').on("click" ,function(e){
		e.preventDefault();
		$('.bottom__header > nav').css("top" ,"-100%");
		$('body,html').css("overflow-y" ,"initial");
	});
});
