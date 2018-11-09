$( document ).on('turbolinks:load', function() {
    document.getElementById('select_layer').addEventListener('change', function(event){select_layer_changed(event);}, false);

});

function select_layer_changed(event) {
    var select_element = document.getElementById('select_layer');
    switch (select_element.options[select_element.selectedIndex].value) {
        case 'no':
            if (mirador_instance.viewer.workspace.windows[0].focusModules.ImageView.annotationState == 'on') {
                $('.mirador-osd-annotations-layer').click();
            }
            break;
        case 'word':
            if (mirador_instance.viewer.workspace.windows[0].focusModules.ImageView.annotationState == 'off') {
                $('.mirador-osd-annotations-layer').click();
            }
            break;
        case 'line':
            console.log('line');
            break;
        case 'block':
            console.log('block');
            break;
        default:
            console.log('problem with select layer list');
    }
}
