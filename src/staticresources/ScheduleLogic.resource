
function classesAvailable(event) {
        selectedClass = $(event).attr("id");  
        $("#selected").fadeIn();
        if (getCourseOutcomes(selectedClass)) { 
            $("#selected").html("Currently placing: " + selectedClass + "&nbsp &nbsp <i>"+ getCourseUnits(selectedClass)+" units</i><br/>Fulfilled Outcome(s): " + getCourseOutcomes(selectedClass));
        } else {
            $("#selected").html("Currently placing: " + selectedClass + "<br/><i>"+ getCourseUnits(selectedClass)+" units</i>");
        }
        firstClick = true;
    }
    function semesterClassClicked(item) {
        $(".unitLabel").css('color','black');
        var classpicked = "#"+$(item).attr("id").substr(0, $(item).attr("id").length - 6);
        selectedClass = $(item).attr("id").substr(0, $(item).attr("id").length - 6);
        firstClick=true;
        $(classpicked).show();
        $("#"+ $(item).attr("id")).remove();
        $("#selected").html("Currently placing: " + $(item).attr("id").substr(0, $(item).attr("id").length - 6));
        calcSemesterUnits();
        $(".classes").css("background-color","lightgreen");
    }
    function semesterClicked(event) {
        var semesterChosen = $(event).parent().attr("id").substr(8);
        calcSemesterUnits();
        if (firstClick) {
            $("#warning").html("");
            $("#warning").hide();
            $(".classes").css("background-color","lightgreen");
            $(".unitLabel").css('color','black');
            $(event).append("<li class=\"listed\" id=\""+selectedClass+"picked\" onclick='semesterClassClicked(this);event.stopPropagation();'>"+selectedClass+ "&nbsp &nbsp &nbsp <i>" + getCourseUnits(selectedClass) +" units</i></li>");
            var classpicked = "#"+selectedClass.toString();
            $(classpicked).hide();
            firstClick = false;
            var preqFound = false;
            var coreqFound = false;
            $("#selected").fadeOut(500);
            var startYear = $("#year").val(); 
            for (var count = 0; count < courseCoreqs.length; count++) {
                coreqFound = false;
                //console.log(courseCoreqs[count].Name);
                if (courseCoreqs[count].Course__c == selectedClass) {
                    var idArray = $("div#semester"+semesterChosen+" > div").map(function(){
                        var linkedCourse = this.id.substr(0, this.id.length - 6);
                        
                        if(linkedCourse == courseCoreqs[count].Name) {
                            coreqFound = true;
                        }
                    }).get();
                    if (coreqFound == false) {
                        $("#warning").append("Warning: The co-requisite for "+ courseCoreqs[count].Course__c + ", " + courseCoreqs[count].Name + " is missing.<br/>");
                        $("#"+ courseCoreqs[count].Name).css("background-color","yellow");
                        $("#warning").show();
                    }
                }
            }
            for (var count = 0; count < coursePreqs.length; count++ ) {
                if (coursePreqs[count].Next_Class__r.Name == selectedClass) {
                    for (index = 0; index < semesterChosen; index++) {   
                        var idArray = $("div#semester"+index+" > div").map(function(){
                            var linkedCourse = this.id.substr(0, this.id.length - 6);
                            if(linkedCourse == coursePreqs[count].Prev_Class__r.Name) {
                                preqFound = true;
                            }          
                        }).get();
                    }
                    if (preqFound == false) {
                        $("#warning").append("Warning: The prequisite for "+ coursePreqs[count].Next_Class__r.Name + ", " + coursePreqs[count].Prev_Class__r.Name + " is missing.<br/>");
                        $("#"+ coursePreqs[count].Prev_Class__r.Name).css("background-color","yellow");
                        $("#warning").show();
                    }
                }
            }
            calcSemesterUnits(); 
            return;
        }    
    }

                                                 
    function getCourseUnits(thisCourse) {
    	for (var index = 0; index < coursesLoaded.length; index++) {
            if (coursesLoaded[index].Name == thisCourse) {
                return coursesLoaded[index].Units__c;
            }  
     	}
		return 0;        
	}
    function getCourseOutcomes(thisCourse) {
    	for (var index = 0; index < coursesLoaded.length; index++) {
   			if (coursesLoaded[index].Name == thisCourse) {
        		return coursesLoaded[index].Outcomes__c;
       		}  
        }
		return 0;        
	}


 function calcSemesterUnits () {
     	$(".unitLabel").css('color','black');
         var totalCount = 0;
         
         for (index1 = 0; index1 < parseInt($("#year").val()); index1++) {
             var semesterCount = 0;
             var spot ='unitCount'+index1;
             document.getElementById(spot).innerHTML=' '+ semesterCount + ' units <br/>';
             
             var idArray = $("div#semester"+index1+" > div").map(function(){
                 var linkedCourse = this.id.substr(0, this.id.length - 6);
                 semesterCount = semesterCount + getCourseUnits(linkedCourse);
                 totalCount + getCourseUnits(linkedCourse);
                 document.getElementById(spot).innerHTML=' ' + semesterCount + ' units <br/>';
                 if (semesterCount > 18) {
                     $("#unitCount"+index1).css('color','red');
                     $("#warning").append("Warning: Unit count limit per semester is 18 units.");
                 }  
             }).get();        
         }    
         return;
    } 
    
    
    function getyeardates(startyear) {
        var startyear = parseInt(startyear);
        var years = [];
        years[0]  = startyear;
        years[1]  = startyear;
        years[2]  = startyear + 1;
        years[3]  = startyear + 1;
        years[4]  = startyear + 2;
        years[5]  = startyear + 2;
        years[6]  = startyear + 3;
        years[7]  = startyear + 3;
        years[8]  = startyear + 4;
        years[9]  = startyear + 4;
        years[10] = startyear + 5;
        years[11] = startyear + 5;
        years[12] = startyear + 6;
        return years;
    }
    function getSemester(n) {
        if (n % 2 == 0) {
            return "SP";
        } else {
            return "FA";
        }
    }
    function setupSemesters() {
        var coursesAvailable = {!courseslistAvailable};
        document.getElementById("available").innerHTML="";
        document.getElementById("main").innerHTML="";
    
        for (var index = 0; index < coursesAvailable.length; index++) {
            $("#available").first().append( 
                $("<div id='" + coursesAvailable[index].Name + "' class='classes' onclick='classesAvailable(this)' > " 
                + coursesAvailable[index].Name + "</div>") 
            );
        }
        var count = parseInt( document.getElementById("year").value );
        var yearHeaders = getyeardates(document.getElementById("startYear").value);
        for (var i = 0; i < count; i++) {
            var semester = document.createElement('div');
            semester.id = 'semester' + i;
            semester.innerHTML = '<div class= \'semesterLabel\' id =\'semesterCount'+i+'\'><h1>'+ getSemester(i+1) + ' ' + 
                yearHeaders[i] +'</h1> </br> <h2 class= \'unitLabel\' id =\'unitCount'+i+'\'></h2></div>' + 
                '<ul class="semesterPicked" onclick="semesterClicked(this)"> </ul>';
            if (i%2 == 0) {
                semester.className = 'even';
            }
            else 
            {
                semester.className = 'odd';
            }
            document.getElementById("main").appendChild(semester);
        }
    }
