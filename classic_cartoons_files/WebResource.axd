// Copyright (c) Microsoft Corporation.  All rights reserved.
//

// The root iws object used to specify the name space of all the iws JavaScript code.
//
function iws(){}

// Constructor for iws.SlideShowItem object.  This object is used to store information
// about images that will appear in a slide show.
//
iws.SlideShowItem = function(owner, imageURL, caption)
{
    this.Owner      = owner;
    this.ImageURL   = imageURL;
    this.Caption    = caption;
    this.Loaded     = false;
    this.Width      = -1;
    this.Height     = -1;
 
    this.MissingImage   = false;
    this.ImgElement     = this.create_img(caption);
    this.CaptionDiv     = this.create_div(caption);

    
    // Find out what sort of opacity is supported in this environment.
    //
    if(typeof this.ImgElement.style.opacity != 'undefined')
    {
	    this.OpacityType = 'w3c';
    }
    else if(typeof this.ImgElement.style.MozOpacity != 'undefined')
    {
	    this.OpacityType = 'moz';
    }
    else if(typeof this.ImgElement.style.KhtmlOpacity != 'undefined')
    {
	    this.OpacityType = 'khtml';
    }
    else if((typeof(this.ImgElement.filters) == 'object') && (!!window.print)) // eliminate mac ie 5 with window.print check.
    {
        this.OpacityType = 'ie';
    }
    else
    {
	    this.OpacityType = 'none';
    }    
}

iws.SlideShowItem.prototype.isLoaded = function()
{
    return this.Loaded;
}

iws.SlideShowItem.prototype.getWidth = function()
{
    return this.Width;
}

iws.SlideShowItem.prototype.getHeight = function()
{
    return this.Height;
}

// Create a new img object to be used by the slide show control.
//
iws.SlideShowItem.prototype.create_img = function(caption)
{
    // Create an image object and append it to the body detecting support for namespaced element 
    // creation, in case we're in the XML DOM.
    //
    var img = this.create_element(window.document.getElementsByTagName('body')[0], 'img');
    img.style.visibility  = "hidden";
    img.style.borderStyle = "solid";
    img.style.borderWidth = "1px";
    img.style.borderColor = "#000000";		
    img.style.position    = "absolute";
    if ((typeof(img.filters) == 'object') && (!!window.print)) // eleminate mac ie 5 with window.print check
    {
        img.style.filter += "progid:DXImageTransform.Microsoft.DropShadow(color=#888888,offX=4,offY=4)";
        img.style.filter += "alpha(opacity=100)";
    }
    
    img.alt = caption;
    
    return img;
}

iws.SlideShowItem.prototype.create_div = function(caption)
{
    var div = this.create_element(this.Owner.SlideShowElement, 'div');
    div.style.visibility  = "hidden";
    div.style.position = "absolute";
    div.style.width = "100%";
    div.style.textAlign = "center";
    div.innerHTML = iws.SlideShowControl.htmlEncode(caption);
    
    return div;
}

iws.SlideShowItem.prototype.create_element = function(parent, type)
{
    var elem = (typeof document.createElementNS != 'undefined') ? document.createElementNS('http://www.w3.org/1999/xhtml', type) : document.createElement(type);
    if (parent)
    {
        parent.appendChild(elem);
    }
    
    return elem;
}


// Takes an element and an opacity value between 0 and 1 and sets the opacity of the element
// to the value specified.
//
iws.SlideShowItem.prototype.setOpacity = function(opacityVal)
{
    switch(this.OpacityType)
    {
	    case 'ie' :
		    this.ImgElement.filters.alpha.opacity = opacityVal * 100.0;
		    break;
			
	    case 'khtml' :
		    this.ImgElement.style.KhtmlOpacity = opacityVal;
		    break;
			
	    case 'moz' : 
		    //restrict max opacity to prevent a visual popping effect in firefox
		    this.ImgElement.style.MozOpacity = (opacityVal == 1 ? 0.9999999 : opacityVal);
		    break;
			
	    default : 
		    //restrict max opacity to prevent a visual popping effect in firefox
		    this.ImgElement.style.opacity = (opacityVal == 1 ? 0.9999999 : opacityVal);
		    break;
    }
}


// Constructor for iws.SlideShowControl object.  The constructor has 4 required parametes
// wich is then followed by the definition of all of the images in the slide show, with
// each image specifying the following parameters in the order (ImageURL, Width, Height, Caption)
// if any one of the paramters is undefined an empty string ('') should be passed in its place.
//
iws.SlideShowControl = function(id, cultureName, title, slideInterval, fadeDuration, startIndex)
{
    this.Id             = id;
    this.CultureName    = cultureName;
    this.Title          = title;
    this.Playing        = false;
    this.Slides         = new Array();
    this.SlideIndex     = -1;
    this.FadeIndex      = -1;

    // Find the expected elements for this slide show control.
    //
    this.SlideShowElement = window.document.getElementById(id);
    this.ContainerElement = window.document.getElementById(id+'_Container');
    this.TitleElement     = window.document.getElementById(id+'_Title');
    this.ImageElement     = window.document.getElementById(id+'_Image');
    this.CaptionElement   = window.document.getElementById(id+'_Cap');
    this.ControlsElement  = window.document.getElementById(id+'_Controls');
    
    this.PausePlayButton  = window.document.getElementById(id+'_PausePlayButton');


    // Add myself to the list now so that when image onload or window.onresize events 
    // come in asynchronasly like they do on Internet Explorer 6 and 7 they can find 
    // the control and and corrisponding SlideShowItem item in the list.
    //
    iws.SlideShowControl.list[iws.SlideShowControl.list.length] = this;

    // All of the paramters after the starIndex should be SlideShowItem image 
    // and capation value pairs.
    //
    for(var i=6; i < arguments.length; i = i + 2)
    {
        var item = new iws.SlideShowItem(this, arguments[i], arguments[i+1]);
        
        this.Slides[this.Slides.length] = item;
        
        // Set the image src here in order to prevent the possibility of loosing the image
        // onload event.  Internet Explorer can call the onload event asynchronasly from the 
        // normal executing code, which can result in the onImageLoad handaler looking for the
        // SlideShowItem in the list before it has been added, unless we start loading the image
        // after the SlideShowItem has been added to the list.
        //
        item.ImgElement.onload = iws.SlideShowControl.onImageLoad;
        item.ImgElement.src    = arguments[i];
    }

    
    // Make sure that the SlideIndex property is set to a valid value.
    //
    this.SlideIndex = startIndex;
    if ((this.SlideIndex < 0) || (this.SlideIndex >= this.Slides.length))
    {
        this.SlideIndex = 0;
    }

    // Setup the slide timer and interval, making sure that the slide interval is at least
    // 500 milliseconds (1/2 second).
    //
    this.SlideTimer     = null;
    this.SlideInterval  = slideInterval * 1000;
    if (this.SlideInterval < 500)
    {
        this.SlideInterval = 500;
    }
    
    // Setup the fade timer and interval, making sure that the fade durration is no longer
    // than the slide interval, so that they do not collide.
    //
    this.FadeTimer          = null;
    this.FadeFramesPerSec   = 20;
    this.fadeFilterIdx      = -1;
    
    
    // Make sure that the fade duration is greater than or equal to 0 and less than 
    // the slide interval.
    //
    this.FadeDuration       = fadeDuration * 1000;
    if (this.FadeDuration > this.SlideInterval)
    {
        this.FadeDuration = this.SlideInterval;
    }
    if (this.FadeDuration < 0)
    {
        this.FadeDuration = 0;
    }
    
    // Calculate the number of framse to use during fades.
    //            
    this.FadeFrames = Math.round((this.FadeDuration * this.FadeFramesPerSec) / 1000);
    if (this.FadeFrames <= 0)
    {
        this.FadeFrames = 1;
    }
	
    // Calculate the interval between fade frames, making sure that it is positive or 0.
    //
    this.FadeInterval = this.FadeDuration / this.FadeFrames
    if (this.FadeInterval < 0)
    {
        this.FadeInterval = 0;
    }

    // Make sure we are register for resize events
    //
    this.resize();
    if (! iws.SlideShowControl.capturedOnResize)
    {
        iws.SlideShowControl.capturedOnResize = true;
        iws.SlideShowControl.oldOnResize = window.onresize;
        window.onresize = iws.SlideShowControl.onResize;
    }

    // Start the slide show
    //
    this.Playing = true;
    this.show_slide(this.SlideIndex, true);
    this.SlideTimer = window.setTimeout(this.Id+'.auto_slide()', this.SlideInterval);
}


// This is a static member of the SlideShowControl class that contains the list of all
// instantiated SlideShowControl objects.
//
iws.SlideShowControl.list = new Array();


// This is a static SlideShowControl function that is called when the
// window.onresize function is called.
//
iws.SlideShowControl.onResize = function()
{
    // Call the onresize function that was there before we captured it
    // if there was one.
    //
    if (typeof(iws.SlideShowControl.oldOnResize) == 'function')
    {
        switch(arguments.length)
        {
            case 0 :
                iws.SlideShowControl.oldOnResize();
                break;
    			
            case 1 :
                iws.SlideShowControl.oldOnResize(arguments[0]);
                break;
	            
            default : 
                iws.SlideShowControl.oldOnResize(arguments[0], arguments[1]);
                break;
        }
    }
    
    for(var i = 0; i < iws.SlideShowControl.list.length; i++)
    {
        iws.SlideShowControl.list[i].resize();
    }
}


// This is a static SlideShowControl function that is called when one of the
// SlideShowItem images is loaded.
//
iws.SlideShowControl.onImageLoad = function()
{    
    for(var i = 0; i < iws.SlideShowControl.list.length; i++)
    {
        for(var j = 0; j < iws.SlideShowControl.list[i].Slides.length; j++)
        {
            var item = iws.SlideShowControl.list[i].Slides[j];
            if (item.ImgElement == this)
            {
                // Due to its asynchronous nature, IE seems to call functions
                // out of order. The following sequence of statements sets
                // the display attribute at the proper place
                item.Width      = item.ImgElement.width;
                item.Height     = item.ImgElement.height;
                item.MissingImage = false;
                item.Loaded       = true;
                
                item.ImgElement.style.display = 'none';
                return;
            }
        }
    }
}

// This function is called when the div containing the images might need to be resized.
//
iws.SlideShowControl.prototype.resize = function()
{
    // Recalculate the max caption height and resize the caption element
    //
    if (this.CaptionElement != null)
    {
        for(var i = 0; i < this.Slides.length; i++)
        {
            if (this.Slides[i].CaptionDiv.clientWidth != this.ImageElement.clientWidth)
            {
                this.Slides[i].CaptionDiv.style.width = this.ImageElement.clientWidth + 'px';
            }
        }

        var maxHeight = 0;
        for(var i = 0; i < this.Slides.length; i++)
        {
            if (this.Slides[i].CaptionDiv.clientHeight > maxHeight)
            {
                maxHeight = this.Slides[i].CaptionDiv.clientHeight;
            }
        }
        
        if ((this.CaptionElement.clientHeight != maxHeight) && (maxHeight > 0))
        {
            this.CaptionElement.style.height = maxHeight + 'px';
        }
    }
    
    
    // Recalculate the element that is used to position the images, and then reposition the 
    // currently visible image properly.
    //
    if ((this.ImageElement !== (void 0)) && (this.ImageElement.clientWidth !== (void 0)))
    {
        var newHeight;
                
        if ((this.SlideShowElement.style.height == '') || (this.SlideShowElement.style.height == 'auto'))
        {
            newHeight = Math.round(this.SlideShowElement.clientWidth * 3 / 4);
        }
        else
        {
            newHeight = this.SlideShowElement.clientHeight;
            if (this.TitleElement != null)
            {
                newHeight -= this.TitleElement.clientHeight;
            }
            if (this.CaptionElement != null)
            {
                newHeight -= this.CaptionElement.clientHeight;
            }
            if (this.ControlsElement != null)
            {
                newHeight -= this.ControlsElement.clientHeight;
            }
        }
        
        if (this.ImageElement.clientHeight != newHeight)
        {
            this.ImageElement.style.height = newHeight + 'px';
        }
            
        if (this.SlideIndex != -1)
        {
            this.position_img(this.Slides[this.SlideIndex].ImgElement, this.SlideIndex, this.ImageElement.clientWidth, newHeight);
        }
        
        if (this.FadeIndex  != -1)
        {
            this.position_img(this.Slides[this.FadeIndex].ImgElement, this.FadeIndex, this.ImageElement.clientWidth, newHeight);
        }
    }    
}

// Resize and reposition the specified image so that it is scaled and in the center 
// of the SlideImageDiv element.
//
iws.SlideShowControl.prototype.position_img = function(img, slideIdx, divWidth, divHeight)
{
    // Don't try and position images that are not loaded yet.
    //
    if ((slideIdx >= 0) && (slideIdx < this.Slides.length) && (this.Slides[slideIdx].isLoaded()))
    {
        // Set the specified img element to the new scaled width and height of the specified slide.
        //
        var flScale = Math.min(1, Math.min(((divWidth - 10) / this.Slides[slideIdx].getWidth()), ((divHeight - 10) / this.Slides[slideIdx].getHeight())));
        
        // Store these values locally for the x and y calculations below.
        // Cannot use img.width and img.height directly because some asynchronous
        // process seems to reset them to the old values and cause miscalculations below.
        var imageWidth  = Math.round(this.Slides[slideIdx].getWidth()  * flScale);
        var imageHeight = Math.round(this.Slides[slideIdx].getHeight() * flScale);
        
        img.width  = imageWidth;
        img.height = imageHeight;

        // Get the absolute coordinates of the slide image div element.
        //
        var tmp = this.ImageElement.offsetParent;
        var x   = this.ImageElement.offsetLeft;
        var y   = this.ImageElement.offsetTop;    
        while(tmp != null)
        {
            x += tmp.offsetLeft;
            y += tmp.offsetTop;
            tmp = tmp.offsetParent;
        }
        
        // Calculate and set the new location of the slide image in the slide image div
        //
        x = x + Math.round((divWidth - imageWidth) / 2);
        y = y + Math.round((divHeight - imageHeight) / 2);
        img.style.left = x + 'px';
        img.style.top  = y + 'px';
    }
}


// If the slide show is currently playing then pause it at the image that is
// currently being displayed.
//
iws.SlideShowControl.prototype.pause = function()
{
    if (this.Playing)
    {
        if (this.SlideTimer != null)
        {
            window.clearTimeout(this.SlideTimer);
            this.SlideTimer = null;
        }
        
        this.Playing = false;
        
        if (this.PausePlayButton != null)
        {
            this.PausePlayButton.src = 'WebResource.axd?d=VmF3745nhrIIu3C9YrUjnpl67v2IGE56egyYWNRvHjjK9npa9pUlzLkNzDHRInrU-OoByGGuLub-Kw6RERWeztKD4k-cj1xREikdN2kWiigytFH9r1uX60tSrv7O5Egdfuz-JmcoGtseJiqGPmq0YW_mLHomoP32SInE_Fyl-GA1&t=633716742020000000';
            this.PausePlayButton.alt = SlideShowControl.ImgBtn.Play.ToolTip;
            this.PausePlayButton.title = SlideShowControl.ImgBtn.Play.ToolTip;
        }
        
        this.show_slide(this.SlideIndex, true);
    }
}


// If the slide show is not currently playing, start the show playing
// from the current image.
//
iws.SlideShowControl.prototype.play = function()
{
    if (! this.Playing)
    {
        this.Playing = true;
        
        if (this.PausePlayButton != null)
        {
            this.PausePlayButton.src = 'WebResource.axd?d=VmF3745nhrIIu3C9YrUjnpl67v2IGE56egyYWNRvHjjK9npa9pUlzLkNzDHRInrU-OoByGGuLub-Kw6RERWeztKD4k-cj1xREikdN2kWiigytFH9r1uX60tSrv7O5Egdfuz-JmcoGtseJiqGPmq0Yd45vFp079fU_wgHsLWY3R41&t=633716742020000000';
            this.PausePlayButton.alt = SlideShowControl.ImgBtn.Pause.ToolTip;
            this.PausePlayButton.title = SlideShowControl.ImgBtn.Pause.ToolTip;
        }
        
        if (this.SlideTimer == null)  // make sure that there is not already a slide show timer going
        {
            if (! this.isFading())
            {
                this.show_slide(this.next_slide_idx(), false);
            }
            this.SlideTimer = window.setTimeout(this.Id+'.auto_slide()', this.SlideInterval);
        }
    }
}


// Stop the slide show if it is currently playing and set the current displayed
// image to the first image of the show with no transition effect.
//
iws.SlideShowControl.prototype.stop = function()
{
    if (this.SlideTimer != null)
    {
        window.clearTimeout(this.SlideTimer);
        this.SlideTimer = null;
    }

    this.Playing = false;
    
    if (this.PausePlayButton != null)
    {
        this.PausePlayButton.src = 'WebResource.axd?d=VmF3745nhrIIu3C9YrUjnpl67v2IGE56egyYWNRvHjjK9npa9pUlzLkNzDHRInrU-OoByGGuLub-Kw6RERWeztKD4k-cj1xREikdN2kWiigytFH9r1uX60tSrv7O5Egdfuz-JmcoGtseJiqGPmq0YW_mLHomoP32SInE_Fyl-GA1&t=633716742020000000';
        this.PausePlayButton.alt = SlideShowControl.ImgBtn.Play.ToolTip;
        this.PausePlayButton.title = SlideShowControl.ImgBtn.Play.ToolTip;
    }
    
    this.show_slide(0, true);
}


// Display the previous image of the current slide show with no transition effect.
//
iws.SlideShowControl.prototype.prev = function()
{
    if (this.SlideTimer != null)
    {
        window.clearTimeout(this.SlideTimer);
        this.SlideTimer = null;
    }
    
    this.show_slide(this.prev_slide_idx(), true);

    if (this.Playing)
    {
        this.SlideTimer = window.setTimeout(this.Id+'.auto_slide()', this.SlideInterval);
    }
}


// Display the next image of the current slide show with no transition effect.
//
iws.SlideShowControl.prototype.next = function()
{
    // If we are not in the middle of fadding into the next slide then
    // advance to the next slide otherwise just interrupt the fade.
    //
    if (this.isFading())
    {
        nextIdx = this.SlideIndex;
    }
    else
    {
        nextIdx = this.next_slide_idx();
    }
    
    if (this.SlideTimer != null)
    {
        window.clearTimeout(this.SlideTimer);
        this.SlideTimer = null;
    }
    
    this.show_slide(nextIdx, true);
    
    if (this.Playing)
    {
        this.SlideTimer = window.setTimeout(this.Id+'.auto_slide()', this.SlideInterval);
    }
}


// Open a new window that displays the current slide show image.
//
iws.SlideShowControl.prototype.show_full = function()
{
    if (this.Slides.length > 0)
    {
        var win = window.open("", "_blank", "width="+this.Slides[this.SlideIndex].Width+", height="+(this.Slides[this.SlideIndex].Height + 35)+", location=no, menubar=no, resizable=no, scrollbars=no");
        
        win.document.open();
        win.document.writeln('<html xmlns="http://www.w3.org/1999/xhtml">');
        win.document.writeln('<head>');
        win.document.writeln('<title>'+iws.SlideShowControl.htmlEncode(this.Title)+'</title>');
        win.document.writeln('<style type="text/css">');
        win.document.writeln('html { background: window; margin: 0px }');
        win.document.writeln('body { background: window; margin: 0px }');
        win.document.writeln('img  { padding-bottom: 4px }');
        win.document.writeln('</style>');
        win.document.writeln('</head>');
        win.document.writeln('<body>');
        win.document.writeln('<form id="form1">');
	    win.document.writeln('<img id="img" src="'+iws.SlideShowControl.htmlEncode(this.Slides[this.SlideIndex].ImageURL)+'" alt="'+iws.SlideShowControl.htmlEncode(this.Slides[this.SlideIndex].Caption)+'" width="'+this.Slides[this.SlideIndex].Width+'" height="'+this.Slides[this.SlideIndex].Height+'" />');
	    win.document.writeln('<div id="btnDiv" align="center">');
	    win.document.writeln('<input type="submit" id="btnClose" name="btnClose" value="'+SlideShowControl.TxtBtn.Close.Text+'" onclick="window.close()" />');
        win.document.writeln('</div>');
        win.document.writeln('</form>');
        win.document.writeln('</body>');
        win.document.writeln('</html>');
        win.document.close();
        
        var btn = win.document.getElementById("btnClose");
        if (btn != null)
        {
            btn.focus();
        }
    }
}



// If the control is currently playing a show then pause it, otherwise
// start it playing again.
//
iws.SlideShowControl.prototype.pause_play = function()
{
    if (this.Playing)
    {
        this.pause();
    }
    else
    {
        this.play();
    }
}


// Show the slide shows current image.  A transitional fade effect will be used unless
// the disableFade value is set to true.
//
iws.SlideShowControl.prototype.show_slide = function(slideIdx, disableFade, delay)
{
    if (this.Slides.length != 0)
    {
        if (delay === (void 0))
        {
            delay = 0;
        }
        
        // If we are in the middle of a fade, set the correct image and opacity immediatly.
        //
        if (this.FadeTimer != null)
        {
            clearInterval(this.FadeTimer);
	        this.FadeTimer = null;

    	    this.Slides[this.SlideIndex].setOpacity(1);
	        this.Slides[this.SlideIndex].ImgElement.style.visibility  = 'visible';
	        this.Slides[this.SlideIndex].ImgElement.style.display = '';

            if (this.FadeIndex != -1)
            {
                this.Slides[this.FadeIndex].ImgElement.style.visibility  = 'hidden';
	            this.FadeIndex = -1;
	        }
        }
    
        if ((slideIdx < 0) || (slideIdx >= this.Slides.length))
        {
            slideIdx = this.SlideIndex;
        }
        
        if (! this.Slides[slideIdx].isLoaded())
        {
            this.Slides[this.SlideIndex].ImgElement.style.visibility = 'hidden';
            this.SlideIndex = slideIdx;
            if ((delay >= 1000) || this.Slides[this.SlideIndex].MissingImage)
            {
                this.Slides[this.SlideIndex].MissingImage = true; 
                this.ImageElement.innerHTML = "<br /><br />"+SlideShowControl.Msg.Missing_Image;
            }
            else
            {
                this.ImageElement.innerHTML = "<br /><br />"+SlideShowControl.Msg.Loading_Image;
                window.setTimeout(this.Id+'.show_slide(-1, true, '+(delay+100)+');', 100);
            }
        }
        else
        {
            this.ImageElement.innerHTML = '';   // make sure any message text has been removed.
            
	        if (disableFade || (this.Slides[slideIdx].OpacityType == 'none') || (this.FadeFrames == 1) || (slideIdx == this.SlideIndex))
	        {
	            // If the fade has been disabled or is not supported or the fade durration is
	            // to short to show a fade then just show the image.  Also if there is only one image
	            // in the show then we are just going to show it we are not going to fade it in and out.
	            //
	            this.Slides[slideIdx].setOpacity(1);
                this.position_img(this.Slides[slideIdx].ImgElement, slideIdx, this.ImageElement.clientWidth, this.ImageElement.clientHeight);
                this.Slides[slideIdx].ImgElement.style.visibility  = 'visible';
                this.Slides[slideIdx].ImgElement.style.display = '';
	            if (slideIdx != this.SlideIndex)
	            {
                    this.Slides[this.SlideIndex].ImgElement.style.visibility  = 'hidden';
                    this.SlideIndex = slideIdx;
	            }
	        }
	        else                                // Otherwise use the opacity functionality
	        {
	            this.FadeIndex = this.SlideIndex;
	            this.SlideIndex = slideIdx;
	            
                this.position_img(this.Slides[this.SlideIndex].ImgElement, this.SlideIndex, this.ImageElement.clientWidth, this.ImageElement.clientHeight);
                this.Slides[this.SlideIndex].setOpacity(0);
                
		        this.FadeCounter = this.FadeFrames;
		        this.FadeTimer = setInterval(this.Id+'.fade()', this.FadeInterval);
	        }
        }
        
        // Set the caption of the image
        //
        if (this.CaptionElement != null)
        {
            this.CaptionElement.innerHTML = iws.SlideShowControl.htmlEncode(this.Slides[this.SlideIndex].Caption);
        }
    }
}

// Fade timer function.  This method should only be called via the 
// window.setInterval() function it should never be called directly.
//    
iws.SlideShowControl.prototype.fade = function()
{
    if (this.FadeCounter == this.FadeFrames)
    {
        this.Slides[this.SlideIndex].ImgElement.style.visibility  = 'visible';
        this.Slides[this.SlideIndex].ImgElement.style.display = '';
    }
    
    this.FadeCounter -= 1;
    if(this.FadeCounter <= 0)
    {
	    clearInterval(this.FadeTimer);
	    this.FadeTimer = null;
    }
	
    // Set the new opacity values for both the original image and the new image.
    //
	var opacityVal = this.FadeCounter / this.FadeFrames;
	
	this.Slides[this.SlideIndex].setOpacity(1 - opacityVal);
	this.Slides[this.FadeIndex].setOpacity(opacityVal);
	
    // The counter has finished so setup the normal image tag and hide the fader image tag.
    //
    if(this.FadeCounter <= 0)
    {
    	this.Slides[this.SlideIndex].setOpacity(1);
	    this.Slides[this.FadeIndex].ImgElement.style.visibility  = "hidden";
	    this.FadeIndex = -1;
    }
}


// Auto slide timer function.  This method should only be called via the 
// window.setTimeout() function it should never be called directly.
//    
iws.SlideShowControl.prototype.auto_slide = function(delay)
{
    this.SlideTimer = null;
    
    if (delay === (void 0))
    {
        delay = 0;
    }
    
    if (this.Playing)
    {
        var nextIdx = this.next_slide_idx();
        if (this.Slides[nextIdx].isLoaded() || this.Slides[this.SlideIndex].MissingImage)
        {
            this.show_slide(nextIdx, false, delay);
            this.SlideTimer = window.setTimeout(this.Id+'.auto_slide();', this.SlideInterval);
        }
        else
        {
            // give it a little more time to load.
            delay = delay + 250;
            if (delay > 1000)
            {
                this.Slides[this.SlideIndex].MissingImage = true;
            }
            this.SlideTimer = window.setTimeout(this.Id+'.auto_slide('+delay+');', 250);
        }
    }
}

// Return the index of the next slide that should be displayed.
//
iws.SlideShowControl.prototype.next_slide_idx = function()
{
    var nextIdx = this.SlideIndex + 1;
    if (nextIdx >= this.Slides.length)
    {
        nextIdx = 0;
    }
    
    return nextIdx;
}

// Move the slide index to the previous slide only if the previous slide image 
// is currently loaded.
//
iws.SlideShowControl.prototype.prev_slide_idx = function()
{
    var prevIdx = this.SlideIndex - 1;
    if (prevIdx < 0)
    {
        prevIdx = this.Slides.length - 1;
    }
    
    return prevIdx;
}


// Return true if the this slide show is in the middle of fading from one image to another.
//
iws.SlideShowControl.prototype.isFading = function ()
{
    return (this.FadeTimer != null);
}

//Added Html Encode function to the file, to be used for assigning the caption to the Full View Slide Show.
//this makes sure the caption remains HTML safe.
iws.SlideShowControl.htmlEncode = function(str)
{
	if (str == null ||  str.length == 0)
	{
		return str;
	}

	str = str.replace( /&/g, "&amp;");
	str = str.replace( /</g, "&lt;");
	str = str.replace( />/g, "&gt;");
	str = str.replace( /\"/g, '&quot;');
	return str;
}

iws.SlideShowControl.htmlDecode = function(str)
{
	if (str == null || str.length == 0)
	{
		return str;
	}
	str = str.replace( /&quot;/g, '"');
	str = str.replace( /&gt;/g, '>');
	str = str.replace( /&lt;/g, '<');
	str = str.replace( /&amp;/g, '&');
	return str;
}