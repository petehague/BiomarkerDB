/* functions to govern logging in */

function login() {
  document.getElementById("workarea").innerHTML='<div id="login"><p><h2>Login</h2></p><form id="upform" action="javascript:sendlogin()"><p class="login">Username:<input type="text" name="username" /></p><p class="login">Password:<input type="password" name="password" /><br /></p><input type="submit" name="submit" value="login" /></div>';
}

function sendlogin() {
 try {
   postal();
   postMan.onreadystatechange=receivelogin;
   postMan.open("POST",systemPath+"/bm_db_web.pl",true);
   postMan.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
   postMan.send("function=login&username="+document.getElementById("upform").username.value+"&password="+document.getElementById("upform").password.value);
   bmusername=document.getElementById("bmusername");
   bmpassword=document.getElementById("bmpassword");
  } catch (err) {
    document.getElementById("workarea").innerHTML=err;
  }
}

function receivelogin() {
  var content;
  var title;
  //  var exdate=new Date();

  if (postMan.readyState==4) {
    content=postMan.responseText;
    title=content.match("<title>.+</title>");
    if (title=="<title>bm_db_login</title>") {
      document.getElementById("workarea").innerHTML='<div id="login"><p><h2>Thankyou for logging in</h2></p></div>';
      //exdate.setDate(exdate.getDate()+7);
      //document.cookie="BMusername="+bmusername+" ;expires="+exdate.toGMTString();
      //document.cookie="BMpassword="+bmpassword+" ;expires="+exdate.toGMTString();
    } else {
      document.getElementById("workarea").innerHTML='<div id="login"><p><h2>Incorrect username or password</h2></p><form id="retry" action="javascript:login()"><input type="submit" name="retry" value="Retry" /></form></div>';
    }

    sessionId=content.match("Logged in as: .+</p><p>W");
    postal();
  }
}

function home() {
  var page;
  page="<h2>Welcome to the Biomarkers Database</h2><br><h3>You are currently logged in as <i>"+sessionId+"</i>, if this is not your username please log out immediately.</h3>";
  document.getElementById("workarea").innerHTML=page;
}

/* Functions that cover viewing and manipulating datasets */

function datasets() {
  document.getElementById("workarea").innerHTML='<div id="login"><h2>Loading datasets...</h2></div>'

  postal();
  postMan.onreadystatechange=receivedata;
  postMan.open("POST",systemPath+"/bm_db_web.pl",true);
  postMan.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
  postMan.send("function=list"); 
}

function receivedata() {
  var content;
  var sets;
  var item;
  var name;
  var page;
  var reg;

  if (postMan.readyState==4) {
    content=postMan.responseText;
    reg=/<div class=\"dataset\">.+<\/div>/g;
    sets=content.match(reg);
    page='<div id="space1"><h2>Available Datasets</h2><table><tr><th scope="col">Set name</th><th scope="col">Files</th></tr>';

    for (item in sets) {
      name=new String(sets[item]);
      if (name.length<100 && !isNumeric(name)) { //filters added because IE handles reg exps stupidly
	name=name.replace("</div>","");
	name=name.replace("<div class=\"dataset\">","");
	page+='<tr><th scope="row">'+name+'</th><td>';
	
	postMan.open("POST",systemPath+"/bm_db_web.pl", false);
	postMan.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
	postMan.send("function=examine&id="+name);
	content=postMan.responseText;
	page+=content.match("<a.+</a>");
	
	page+='</td><td><a class="blue" href="javascript:killdata(\''+name+'\')">Delete dataset</a></td></tr>';
	postal();
      }
    }

    

    page+='</table></div>';
    document.getElementById("workarea").innerHTML=page;
  }
}

function killdata(name) {
  document.getElementById("workarea").innerHTML='<div id="login"><h2>Warning</h2><p>Are you sure you want to delete '+name+'?</p><form id="yesform" action="javascript:reallykilldata(\''+name+'\')"><input type="submit" name="submit" value="Yes" /></form><form id="noform" action="javascript:datasets()"><input type="submit" name="submit" value="No" /></form></div>';
}

function reallykilldata(name) {
  postMan.onreadystatechange=datadies;
  postMan.open("POST",systemPath+"/bm_db_web.pl", true);
  postMan.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
  postMan.send("function=delete&id="+name);
  document.getElementById("workarea").innerHTML='<div id="login"><h2>Deleting '+name+'...</h2></div>';
}

function datadies() {
  if (postMan.readyState==4) {
    document.getElementById("workarea").innerHTML='<div id="login"><h2>Dataset has been deleted</h2><form id="okform" action="javascript:datasets()"><input type="submit" name="submit" value="Ok" /></form></div>';
    postal();
  }
}

/* Functions that govern uploading datasets */

function extractIFrameBody(iFrameEl) {
  var doc = null;
  if (iFrameEl.contentDocument) { // For NS6 and Mozilla
    doc = iFrameEl.contentDocument; 
  } else if (iFrameEl.contentWindow) { // For IE5.5 and IE6
    doc = iFrameEl.contentWindow.document;
  } else {
    return null;
  }
  
  //Internet Explorer hack
  if (doc){
    doc.open();
    doc.write('Loading AJAX...');
    doc.close();
  }
  return doc.body;
}

function upload() {
  var framebody;
  var lform;

  if (sessionAction) {
    //If user is returning to the page from going elsewhere
    document.getElementById("workarea").innerHTML='<h2>Still processing '+sessionAction+'</h2><hr><div id="status"></div>';
  } else {
    //If users is visiting page when no upload is in progess
    document.getElementById("workarea").innerHTML='<div id="space1"><h2>Upload a dataset</h2><div id="rules"><p>Rules for uploading datasets:</p><ul><li>Dataset must be compressed into a .zip format archive</li><li>Filenames in the dataset should conform to the following format: <b>projectname-date-samplenumber<i>shotletter</i>.txt</b>, for example xx-230608-23b.txt</li><li>Only .txt files that contain mass spectromotry data should be in the archive</ul></div><div id="ucont"><iframe id="loadform" height="50px"></iframe><form id="lform" method="POST" action="javascript:getfile()" enctype="multipart/form-data"><input type="submit" name="function" value="Upload File" /></form></div><div id="status"></div></div>';

    framebody=extractIFrameBody(document.getElementById("loadform"));
    framebody.innerHTML='<form id="fileform" method="POST" action="'+systemPath+'/bm_db_web.pl" enctype="multipart/form-data"><input type="file" name="sourcefile" /><input type="hidden" name="function" value="upload" /></form>';
  }
}

function getfile() {
  try {
  var framebody=document.getElementById("loadform").contentWindow.document;
  var filetext=framebody.getElementById("fileform").sourcefile.value.match("[a-zA-Z0-9_]+\.zip");
  var dirname=filetext[0].replace(".zip","");
  } catch (err) { alert("Cannot process filename"); }

  if (dirname) {
    framebody.getElementById("fileform").submit();
    document.getElementById("ucont").visibility="hidden";
    document.getElementById("ucont").display="none";
    document.getElementById("status").innerHTML="<h3>Sending data to server...</h3>";
    sessionAction=dirname;
    sessionToken=1;
    sessionUpload=setInterval("progressbar('"+dirname+"');",1000);
  }
}

function progressbar(dir) {
  if (sessionToken) {
    postal();
    postMan.onreadystatechange=displayprogressbar;
    postMan.open("POST",systemPath+"/bm_db_web.pl",true);
    postMan.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
    postMan.send("function=status&id="+dir);
    sessionToken=0;
  }
}


function displayprogressbar() {
  var content;
  var action;
  var percent;
  var text;

  //Check if the current request has returned 
  if (postMan.readyState==4) {
    sessionToken=1;
    if (content=postMan.responseText) {
      //If the response exists, print it, otherwise display waiting message
      try {
	if (text=content.match('<div.+<div id="percent">')) {
	  action=text[0].replace('<div id="action">',"");
	  action=action.replace('<div id="percent">',"");
	  action=action.replace('</div>',"");
	  text=content.match('<div id="percent">.+</div>');
	  percent=text[0].replace('<div id="percent">',"");
	  percent=percent.replace('</div>',"");
	  document.getElementById("status").innerHTML="<h3>"+action+" "+percent+"%</h3>";
	  document.getElementById("ucont").innerHTML="";
	} else {
	  document.getElementById("status").innerHTML="<h3>Still uploading...</h3>";
	}
      } catch (err) { 
	try {
	  document.getElementById("status").innerHTML="<h3>Waiting for response...</h3>"; 
	} catch (err2) {}
      }
    }

    //When the upload is complete, report it and close the interval
    if (action=="Complete") { 
      document.getElementById("status").innerHTML="<h3>Upload Complete!</h3>";
      clearInterval(sessionUpload); 
      sessionUpload=0;
      sessionAction=0;
    }
  }
}

/* Function for logging out */

function logout() {
  document.getElementById("workarea").innerHTML='<div id="login"><p><h2>You are now logged out</h2></p><form id="retry" action="javascript:login()"><input type="submit" name="retry" value="Continue" /></form></div>';
  sessionId="";
  document.cookie='username=none; expires=Tue, 5 Aug 2008 09:00:00 UTC; path=/'
}

/* Function to reset postMan object (needed because of IE being thick) */

function postal() {
  try {
    postMan=new XMLHttpRequest(); //user has a good browser - firefox, opera, safari
  } catch (err) {
    try {
      postMan=new ActiveXObject("Msxml2.XMLHTTP"); //user is a bit of a noob - IE 6+
    } catch (err) {
      try {
	postMan=new ActiveXObject("Microsoft.XMLHTTP"); //even more of a noob - older IE
      } catch (err) {
	alert("Your browser does not support AJAX, please update it!"); //user is a time traveller from the 1990s - IE<5, Netscape, Lynx or some wierd shit like that
      }
    }
  }
}

/* Function to change user settings */
function settings() {
  document.getElementById("workarea").innerHTML='<div id="login"><h2>Loading settings...</h2></div>';

  postal();
  postMan.onreadystatechange=receivesettings;
  postMan.open("POST",systemPath+"/bm_db_web.pl",true);
  postMan.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
  postMan.send("function=settings"); 
}

function receivesettings() {
  if (postMan.readyState==4) {
    content=postMan.responseText;
    page='<div id="space1"><h2>Change Settings</h2>'+content+'</div>';
    document.getElementById("workarea").innerHTML=content;
  }
}


/* Function to help filter numeric values spit out by Microsofts piece of crap browser */

function isNumeric(number) {
  if (number.match("^[0-9]+$")) { return 1; } else { return 0; }
}
