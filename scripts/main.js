// Para mostrar y esconder las notas apartes:
$('.note .note-content').toggleClass('hide');

$('.note .aside-header').click(function(ev) {
	console.log('clicked')
    var noteContentElement = $(ev.target.parentElement.parentElement).find('.note-content');
    console.log('noteContentElement = ', noteContentElement);
    noteContentElement.toggleClass('hide');
});