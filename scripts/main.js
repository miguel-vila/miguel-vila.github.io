// Para mostrar y esconder las notas apartes:
$('.note .note-content').toggleClass('hide');

$('.note .aside-header').click(function(ev) {
    var noteContentElement = $(ev.target.parentElement).next();
    noteContentElement.toggleClass('hide');
});