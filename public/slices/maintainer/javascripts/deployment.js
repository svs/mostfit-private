$(function() {
    setup_ajax_forms();

    $("input[name=upgrade_db]").next("span").hide().end().change(function() {
	($(this).filter(":checked").length > 0) ? $(this).next("span").show() : $(this).next("span").hide();
    });

    $("input[name=branch_type]").change(function() {
	var branch_type = $("input[name=branch_type]:checked").val();
	$("[name$=branch]").hide();
	$("#branch-type-"+branch_type).show();
    });
    
    $("#deployment-log table a.confirm:eq(0)").remove();
});