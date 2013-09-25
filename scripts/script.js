$('#content img').each(function(i, img) {
    var $img = $(img);
    $img.wrap('<a class="image" target="blank" href="' + $img.attr('src') + '"></a>');
});

