// Para mostrar y esconder las notas apartes:
$('.note .note-content').toggleClass('hide');

$('.note .aside-header .clickme').click(function(ev) {
    var noteContentElement = $(ev.target.parentElement.parentElement).find('.note-content');
    noteContentElement.toggleClass('hide');
});