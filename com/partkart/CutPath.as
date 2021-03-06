﻿package com.partkart{

	import flash.display.*;
	import flash.events.*;
	import flash.geom.Point;
	import flash.geom.Matrix;
	import flash.geom.Transform;
	import flash.geom.Rectangle;

	import com.tink.display.HitTest;

	public class CutPath extends Path{

		// link to the original path that this cutpath is an approximation of
		public var parentpath:Path;

		public var originalpath:Array = new Array(); // keep a reference to the original path segments

		protected var fillmap:BitmapData;
		protected var trans:Matrix;
		protected var region:Rectangle;
		protected var fillbitmap:Bitmap;

		public var pocketdepth:int;

		// a list of starting values for tabs
		public var tabs:Array;

		public var tabpositions:Array;

		// tab currently being dragged
		public var dragtab:Tab;

		public function CutPath():void{
			super();
		}

		/*protected override function setLineStyle(style:int):void{
			linestyle = style;
			switch(style){
				case 0: // straight line
				if(active == true){
					graphics.lineStyle(2,0x009911,1,true,LineScaleMode.NONE);
				}
				else{
					graphics.lineStyle(1,0x009911,1,true,LineScaleMode.NONE);
				}
				break;
				case 1: // curved line
				if(active == true){
					graphics.lineStyle(2,0x3366ff,1,true,LineScaleMode.NONE);
				}
				else{
					graphics.lineStyle(1,0x3366ff,1,true,LineScaleMode.NONE);
				}
				break;
				case 2: // semi-transparent guide line
					graphics.lineStyle(1, 0x000000, 0.3, false, LineScaleMode.NONE);
				break;
			}
		}*/

		protected override function attachActions():void{
			// we don't want cut paths to be selectable
		}

		public override function addSegment(seg:Segment):void{
			if(seg is CircularArc){
				var seg1:CircularArc = seg as CircularArc;
				originalpath.push(seg1.arcclone());
			}
			else{
				originalpath.push(seg.clone());
			}
			super.addSegment(seg);
		}

		public function addSegments(list:Array):void{
			if(seglist == null){
				seglist = list;
			}
			else{
				seglist = seglist.concat(list);
			}
			for each(var seg:Segment in list){
				addChild(seg);
			}
		}

		protected override function renderLine(seg:Segment, sprite:Sprite = null):void{
			if(active == true){
				setLineStyle(4);
			}
			else{
				setLineStyle(3);
			}
			super.renderLine(seg, sprite);
		}

		protected override function renderArc(seg:ArcSegment, sprite:Sprite = null):void{
			if(active == true){
				setLineStyle(6);
			}
			else{
				setLineStyle(5);
			}
			super.renderArc(seg, sprite);
		}

		public function redrawCuts(diameter:Number):void{
			graphics.clear();
			renderClear();

			graphics.lineStyle(diameter*Global.zoom, 0xff0000, 0.2,false,LineScaleMode.NORMAL,CapsStyle.ROUND);
			graphics.moveTo(seglist[0].p1.x*Global.zoom, -seglist[0].p1.y*Global.zoom);

			for(var i:int=0; i<seglist.length; i++){
				if(seglist[i] is CircularArc){
					renderFillArc(seglist[i], Global.zoom, 3, true);
				}
				else{
					renderFillLine(seglist[i], Global.zoom, true);
				}
			}
		}

		public function redrawStartCut(prev:Point):void{
			renderFillLine(new Segment(prev,seglist[0].p1), Global.zoom, false);
		}

		// renders a filled bitmap for invalid edge removal
		protected function renderFill(radius:Number, cutlist:Array):Number{

			//this.cacheAsBitmap = false;

			var cutpath:CutPath;

			for each(cutpath in cutlist){
				addChild(cutpath);
				for each(var seg:Segment in cutpath.seglist){
					cutpath.addChild(seg);
				}
				cutpath.redraw();
			}
			//cacheAsBitmap = false;
			//Math.min(Global.tolerance*9,0.025)
			//(Math.abs(2*radius))*Global.zoom - 1

			// 255 is the max line thickness, which is a bottleneck for our application
			// thus we use the thickest line possible, and define a scaling factor around that
			region = this.getBounds(this);

			var factor:Number = (255)/(Math.abs(2*radius) - Global.bitmaptolerance);
			//var factor:Number = (255)/(Math.abs(2*radius)*0.97);
			//var factor:Number = 255/(Math.abs(2*radius));
			var linethickness:Number = 255;

			var spritewidth:Number = ((region.width/Global.zoom)+2*Math.abs(radius))*factor;
			var spriteheight:Number = ((region.height/Global.zoom)+2*Math.abs(radius))*factor;

			factor += 0.5*Global.bitmaptolerance*Math.max(spritewidth,spriteheight);

			if(spritewidth > Global.bitmapsize){
				factor *= Global.bitmapsize/spritewidth;

				// note: this is an ugly hack! I noticed that the factor does not seem right when the contour is very large (1~2 feet), this is just a manual compensation - a proper fix must be added!
				//factor += 0.2*Global.bitmaptolerance*spritewidth;

				linethickness *= Global.bitmapsize/spritewidth;

				spriteheight *= Global.bitmapsize/spritewidth;
				spritewidth = Global.bitmapsize;
			}
			if(spriteheight > Global.bitmapsize){
				factor *= Global.bitmapsize/spriteheight;

				//factor += 0.2*Global.bitmaptolerance*spriteheight;
				linethickness *= Global.bitmapsize/spriteheight;

				spritewidth *= Global.bitmapsize/spriteheight;
				spriteheight = Global.bitmapsize;
			}

			// thickness must be an integer

			//linethickness -= 2;

			factor *= Math.floor(linethickness)/linethickness;
			linethickness = Math.floor(linethickness);

			graphics.lineStyle(linethickness,0x000000,1,false,LineScaleMode.NORMAL,CapsStyle.ROUND);


			//var linewidth:Number = Math.floor(factor*(Math.abs(2*radius)) - 3);

			//graphics.moveTo(seglist[0].p1.x*factor, -seglist[0].p1.y*factor);

			//addChild(addDot(seglist[0].p1));

			//graphics.clear();

			while(numChildren > 0){
				removeChildAt(0);
			}

			for each(cutpath in cutlist){
				for(var i:int=0; i<cutpath.seglist.length; i++){
					if(cutpath.seglist[i] is CircularArc){
						renderFillArc(cutpath.seglist[i], factor);
					}
					else{
						renderFillLine(cutpath.seglist[i], factor);
					}
				}
			}

			region = this.getBounds(this);

			var scale:Number; // scaling factor for bitmap

			var idealwidth:Number = region.width;
			var idealheight:Number = region.height;

			if(idealwidth > Global.bitmapsize){
				idealheight *= Global.bitmapsize/idealwidth;
				idealwidth = Global.bitmapsize;
			}

			if(idealheight > Global.bitmapsize){
				idealwidth *= Global.bitmapsize/idealheight;
				idealheight = Global.bitmapsize;
			}

			scale = idealwidth/region.width;

			trans = new Matrix(scale,0,0,scale, -region.x*scale,-region.y*scale);

			fillmap = new BitmapData(region.width*scale,region.height*scale,true,0);
			fillmap.draw(this, trans);

			// this renders the bitmap on stage for debugging purposes
			/*fillbitmap = new Bitmap(fillmap);
			var inv:Matrix = trans.clone();
			inv.invert();
			fillbitmap.transform.matrix = inv;
			fillbitmap.width *= Global.zoom/factor;
			fillbitmap.height *= Global.zoom/factor;
			fillbitmap.x *= Global.zoom/factor;
			fillbitmap.y *= Global.zoom/factor;*/
			//this.parent.parent.addChild(fillbitmap);

			graphics.clear();

			return factor;
		}

		public function renderFillLine(segment:Segment, factor:Number, continuous:Boolean = false, sprite:Sprite = null):void{
			if(sprite == null){
				sprite = this;
			}

			if(continuous == false){
				sprite.graphics.moveTo(segment.p1.x*factor, -segment.p1.y*factor);
			}
			sprite.graphics.lineTo(segment.p2.x*factor, -segment.p2.y*factor);
		}

		// this function renders a circular arc with line segments instead of bezier curves (bezier curves are sometimes unstable with dirty/extreme input)
		public function renderFillArc(arc:CircularArc, factor:Number, tol:Number = 0, continuous:Boolean = false, sprite:Sprite = null):void{

			var theta:Number;
			var skiplast:Boolean = true;
			if(tol == 0){
				theta = 0.25*Math.sqrt(Global.tolerance/Math.abs(arc.radius*2)); // this dtheta ensures that the segments never deviate past the global tolerance values
			}
			else{
				theta = tol*Math.sqrt(Global.tolerance/Math.abs(arc.radius*2));
				skiplast = false;
			}
			var angle:Number = Math.atan2(arc.p1.y - arc.center.y, arc.p1.x - arc.center.x);

			var totalangle:Number = Global.getAngle(new Point(arc.p1.x - arc.center.x, arc.p1.y - arc.center.y),new Point(arc.p2.x - arc.center.x, arc.p2.y - arc.center.y));

			var segs:int = Math.ceil(Math.abs(totalangle/theta));
			theta = totalangle/segs;

			if (segs>0){
				var x1:Number;
				var y1:Number;

				var tp1:Point = arc.p1; // note that we start at the "end" of the arc as defined in arcSegment
				var tp2:Point;

				var sinangle:Number;
				var cosangle:Number;

				// Loop for drawing arc segments
				// note: sometimes (very rarely) the vector renderer "overshoots" a little. We don't draw the last segment to compensate
				if(skiplast == true && segs > 1){
					segs--;
				}
				for (var i:int = 0; i<segs; i++){
						angle += theta;

						sinangle = Math.sin(angle);
						cosangle = Math.cos(angle);

						x1 = arc.center.x + (Math.abs(arc.radius)*cosangle);
						y1 = arc.center.y + (Math.abs(arc.radius)*sinangle);

						tp2 = new Point(x1,y1);

						renderFillLine(new Segment(tp1, tp2),factor,continuous, sprite);

						tp1 = tp2;
				}
			}
		}

		// 1 = counterclockwise, 2 = clockwise
		public function setDirection(dir:int):void{
			makeContinuous();

			if(dir != getDirection()){
				reversePath();
			}
		}

		public function getDirection():int{
			var area:Number = getPolygonArea();
			if(area < 0){
				return 1; // counterclockwise
			}
			else if(area > 0){
				return 2; // clockwise
			}
			return 0;
		}

		// returns the area enclosed by the start/end points of each segment
		// assumes that the path is closed
		public function getPolygonArea(arealist:Array = null):Number{
			var area:Number = 0;

			if(arealist == null){
				arealist = seglist;
			}

			for each(var seg in arealist){
				var width:Number = seg.p2.x - seg.p1.x;
				// rectangular area
				area += width*seg.p2.y;

				// triangular area
				area += 0.5*width*(seg.p1.y - seg.p2.y);
			}

			return area;
		}

		// constructs an offset of this cutpath from the given seglist
		// returns array of seglists, each of which represents a cutpath loop
		// if "clean" flag is given, the input cutlist is not checked for intersections
		public function offset(cutlist:Array, radius:Number, clean:Boolean = false):Array{

			var cutpath:CutPath;

			// remove small loops that would be offset out of existence (!important - without this small loops may be offset larger and larger ad infinitum!)
			var minarea:Number = Math.PI*Math.pow(radius,2);

			for(var i:int=0; i<cutlist.length; i++){
				cutpath = cutlist[i];
				var area:Number = getPolygonArea(cutpath.seglist);
				if(this.pocketdepth && this.pocketdepth > 0 && (Math.abs(area) < minarea)){
					cutlist.splice(i,1);
					i--;
				}
			}

			if(cutlist.length == 0){
				return new Array();
			}

			// remove intersections in the source boundary curve (currently only effective for local invalid loops, will not work with global invalid loops!)
			if(clean == false){
				for each(cutpath in cutlist){
					cutpath.intersect(radius, true);
				}
			}

			// store copy of source boundary curve (will need it when adding joining circles)
			for each(cutpath in cutlist){
				cutpath.originalpath = cutpath.seglist;
			}

			// make deep copy of seglist (contents of seglist still belong to a path object, we don't want to change the boundary path!)
			for each(cutpath in cutlist){
				cutpath.clonePath();
			}

			// renders a fill bitmap (will need this for removing invalid loops later)
			var factor:Number = renderFill(radius, cutlist);

			// simple offset of each segment
			for each(cutpath in cutlist){
				cutpath.simpleoffset(radius);
			}

			// merge sequential segments if endpoints are touching, compute intersections and trim sequential segments if intersecting
			for each(cutpath in cutlist){
				cutpath.joinSequence();
			}

			// if sequential segments are not joined, join them with joining circles
			for each(cutpath in cutlist){
				cutpath.addCircles(radius);
			}

			// this is mainly needed to resolve near-circular offsets
			for each(cutpath in cutlist){
				cutpath.cleanup(0.5);
			}

			/*for each(cutpath in cutlist){
				for(i=0 ;i<cutpath.seglist.length; i++){
					if(cutpath.seglist[i] is CircularArc){
						cutpath.seglist[i].recalculateCenter();
						cutpath.seglist[i] = cutpath.seglist[i].arcclone();
					}
				}
			}*/

			// now we are done with path specific actions. Lump all the cutpaths into a single meshed seglist for intersection detection
			var chains:Array = new Array();

			for each(cutpath in cutlist){
				chains = chains.concat(cutpath.getMonotoneChains());
				if(contains(cutpath)){
					removeChild(cutpath);
				}
			}

			/*for each(var chain in chains){
				for each(var seg in chain){
					this.parent.addChild(addDot(seg.p1));
					this.parent.addChild(addDot(seg.p2));
				}
			}*/

			/*for each(var chain in chains){
				addChild(addDot(chain[0].p1));
			}*/

			// find all intersections of offset curve, slice segments in two where intersections occur
			intersect(radius, false, chains);

			// remove all segments that lie on the fillmap
			removeInvalid(factor);

				return processLoops();
				/*var isclosed:Boolean = this.isClosed();

				for each(var c:MonotoneChain in chains){
					seglist = seglist.concat(c);
				}
				var returnpath:Path = new Path();
				for each(var seg:* in seglist){
					returnpath.addSegment(seg);
				}
				var scene:SceneGraph = this.parent.parent as SceneGraph;
				scene.addPath(returnpath);
				return new Array();*/
		}

		// returns true if offset is no longer necessary (tool will remove all material within)
		// note: may fail for irregular shapes, such as long slivers where internal area is large but material will be removed anyways..
		/*public function isSmall(radius:Number):Boolean{
			var area:Number = getPolygonArea(seglist);
			if(area < 0 && Math.abs(area) < Math.PI*Math.pow(radius,2)){
				return true;
			}

			return false;
		}*/

		/*public function cloneCutPath():CutPath{
			var cutpath:CutPath = new CutPath;
			cutpath.direction = direction;
			cutpath.seglist = seglist;
			cutpath.clonePath();
			return cutpath;
		}*/

		// make a deep copy of the seglist for offsetting (we don't want to change the original!)
		public function clonePath():void{
			var newseglist:Array = new Array();

			for each(var seg in seglist){
				if(seg is CircularArc){
					newseglist.push(seg.arcclone());
				}
				else{
					newseglist.push(seg.clone());
				}
			}

			while(numChildren > 0){
				removeChildAt(0);
			}

			for each(seg in newseglist){
				addChild(seg);
			}

			seglist = newseglist;
		}

		protected function simpleoffset(radius:Number):void{

			// offset each segment

			for(var i:int=0; i<seglist.length; i++){
				seglist[i].offset(radius)
				seglist[i].name = i; // store a link to the original segment it was offset from
			}
		}

		// cleanup the raw offset curves by joining segment start/end points, and finding sequential intersections
		public function joinSequence(tol:Number = 0.5):void{
			for(var i:int=0; i<seglist.length-1; i++){
				if(seglist[i].p2 != seglist[i+1].p1 && Global.withinTolerance(seglist[i].p2, seglist[i+1].p1, tol)){
					seglist[i].p2 = seglist[i+1].p1;
				}
				else if(seglist[i].p2 != seglist[i+1].p1){
					// try to find intersection
					splitSegments(i, i+1);
				}
			}

			if(seglist[seglist.length-1].p2 != seglist[0].p1 && Global.withinTolerance(seglist[seglist.length-1].p2, seglist[0].p1, tol)){
				seglist[seglist.length-1].p2 = seglist[0].p1;
			}
			else{
				splitSegments(seglist.length-1,0);
			}
		}

		protected function splitSegments(index1:int,index2:int):void{

			if(index1 < 0 || index2 < 0){
				return;
			}

			var seg1 = seglist[index1];
			var seg2 = seglist[index2];

			var ip:Array;
			var p:Point;

			if(seg1 is CircularArc && seg2 is CircularArc){
				ip = arcArcIntersect(seg1, seg2);
			}
			else if(!(seg1 is CircularArc) && seg2 is CircularArc){
				ip = lineArcIntersect(seg1,seg2);
			}
			else if(seg1 is CircularArc && !(seg2 is CircularArc)){
				ip = lineArcIntersect(seg2,seg1);
			}
			else{
				p = Global.lineIntersect(seg2.p1, seg2.p2, seg1.p1, seg1.p2, true);
			}

			if(ip != null){
				p = ip[0];
			}


			if(p != null){
				//this.parent.parent.addChild(addDot(p));

				var segname:String = seglist[index1].name;

				if(seg1 is CircularArc){
					var newarc:CircularArc = new CircularArc(seg1.p1,p,seg1.center,seg1.radius);
					seglist[index1] = newarc;
				}
				else{
					var newsegment:Segment = new Segment(seg1.p1,p);
					seglist[index1] = newsegment;
				}

				seglist[index1].name = segname;

				segname = seglist[index2].name;

				if(seg2 is CircularArc){
					var newarc2:CircularArc = new CircularArc(p,seg2.p2,seg2.center,seg2.radius);
					seglist[index2] = newarc2;
				}
				else{
					var newsegment2:Segment = new Segment(p,seg2.p2);
					seglist[index2] = newsegment2;
				}

				seglist[index2].name = segname;
			}
		}

		// adds joining circles to separated segments
		// only add if the normal angle between two segments are acute
		protected function addCircles(radius:Number):void{
			//var offset:Array = cutpath.seglist;

			var circle:CircularArc;

			for(var i:int=0; i<seglist.length-1; i++){
				circle = getCircle(seglist[i], seglist[i+1], radius);
				if(circle != null){
					seglist.splice(i+1,0,circle);
					i++;
				}
			}

			// handle beginning and end points
			circle = getCircle(seglist[seglist.length-1],seglist[0], radius);
			if(circle != null){
				seglist.push(circle);
			}

			//trace(offset);
		}

		protected function getCircle(offset1:Segment, offset2:Segment, radius:Number):CircularArc{
			var off1;
			var off2;

			if(offset1.p2 == offset2.p1){
				return null;
			}

			var norm1:Point;
			var norm2:Point;

			if(offset1 is CircularArc){
				off1 = offset1 as CircularArc;
			}
			else{
				off1 = offset1;
			}
			if(offset2 is CircularArc){
				off2 = offset2 as CircularArc;
			}
			else{
				off2 = offset2;
			}

			return new CircularArc(off1.p2, off2.p1, originalpath[off1.name].p2.clone(), radius);
		}

		// a monotone chain is a sequence of segments that do not self-intersect (monotone in the x direction)
		// we use this to speed up intersection detection
		protected function getMonotoneChains():Array{

			var point:Point;

			// before extracting monotone chains, we must split up arcs so that they are monotone with respect to the sweep direction (x axis)
			for(var i:int=0; i<seglist.length; i++){
				if(seglist[i] is CircularArc){
					var circle:CircularArc = seglist[i] as CircularArc;
					if(((circle.p1.y > circle.center.y && circle.p2.y < circle.center.y) || (circle.p1.y < circle.center.y && circle.p2.y > circle.center.y)) && Math.abs(circle.p1.y - circle.center.y) > 0.0000000001 && Math.abs(circle.p2.y - circle.center.y) > 0.0000000001){
						/*if(circle.p1.x > circle.center.x && circle.p2.x > circle.center.x){
							point = new Point(circle.center.x + Math.abs(circle.radius), circle.center.y);
						}
						else if(circle.p1.x < circle.center.x && circle.p2.x < circle.center.x){
							point = new Point(circle.center.x - Math.abs(circle.radius), circle.center.y);
						}
						else{
							point = new Point(circle.center.x - circle.radius, circle.center.y);
						}*/
						point = new Point(circle.center.x + Math.abs(circle.radius), circle.center.y);

						if(!circle.onArc(point)){
							point = new Point(circle.center.x - Math.abs(circle.radius), circle.center.y);

							/*if(!onArc(point,circle)){
								// if neither point is on the arc, the split point must be very close to one of the end points, in which case nothing needs to be done
								continue;
							}*/
						}

						var arc1:CircularArc = new CircularArc(circle.p1,point,circle.center,circle.radius);
						var arc2:CircularArc = new CircularArc(point,circle.p2,circle.center,circle.radius);

						seglist.splice(i,1,arc1,arc2);
						i++;
					}
				}
			}

			// start monotone chain extraction
			var chains:Array = new Array(new MonotoneChain());


			var pdir:Boolean; // previous direction true = left, false = right
			var cdir:Boolean; // current direction
			var odir:Boolean; // keep reference to original direction for merging start and end chains

			if(seglist[0].p1.x > seglist[0].p2.x){
				pdir = false;
			}
			else{
				pdir = true;
			}

			odir = pdir;

			var len:int = seglist.length;
			for(i=0; i<len; i++){
				if(seglist[i].p1.x > seglist[i].p2.x){
					cdir = false;
				}
				else{
					cdir = true;
				}

				// start a new chain if a direction change occurs
				if(cdir != pdir){
					pdir = cdir;
					chains.push(new MonotoneChain());
					chains[chains.length-1].push(seglist[i]);
				}
				else{
					chains[chains.length-1].push(seglist[i]);
				}

				seglist[i].name = i;
			}

			// merge first and last chains if in the same direction
			if(cdir == odir && chains.length > 1){
				var firstchain:MonotoneChain = chains.shift();
				var monochain:MonotoneChain = new MonotoneChain();
				var newchain:Array = chains[chains.length-1].concat(firstchain);
				for each(var seg in newchain){
					monochain.push(seg);
				}
				chains[chains.length-1] = monochain;
			}

			for each(var chain in chains){
				//addChild(addDot(chain[0].p1));
				// every monotonic chain must be oriented left to right for the sweep line intersection algorithm
				if(chain[0].p1.x > chain[chain.length-1].p2.x){
					for(i=0; i<chain.length; i++){
						var n:String = chain[i].name;
						chain[i] = chain[i].reverse();
						chain[i].name = n;
					}
					chain.reverse();
					chain.reversed = true;
				}
			}

			return chains;
		}

		// finds intersections and removes unwanted loops
		// uses a sweep line technique for intersection calculation
		protected function intersect(radius:Number, trim:Boolean = false, chains:Array = null):void{

			if(chains == null){
				chains = getMonotoneChains();
			}

			var activechains:Array = new Array(); // active chains contain a list of unprocessed monotone chains, sorted by x value
			var sweepchains:Array = new Array(); // sweep chains are chains that are currently on the sweep line, sorted by y value at the intersection point

			var chain:MonotoneChain;

			for each(chain in chains){
				chain.frontvalue = chain[0].p1.x;
				activechains.push(chain);
			}

			activechains.sortOn("frontvalue", Array.NUMERIC);

			var i:int;

			var ip:Array;

			var seg1;
			var seg2;

			var trim1:Boolean; // indicates that the front part of the segment should be trimmed off
			var trim2:Boolean;

			var m:Number;

			var newarc1:CircularArc;
			var newarc2:CircularArc;
			var newarc3:CircularArc;

			var newsegment1:Segment;
			var newsegment2:Segment;
			var newsegment3:Segment;

			var intersections:Array = new Array();

			var previntersect:Boolean = false; // we want to stay on the same frontindex if the last iteration produced an intersection
			var frontchain:MonotoneChain = activechains[0];

			//sweepchains = activechains;

			while(activechains.length > 0){
				/*if(previntersect == true){
					frontchain.frontindex--;
				}*/
				frontchain = activechains[0];

				if(frontchain.frontindex < frontchain.length){
					frontchain.frontindex++;
					if(frontchain.frontindex == frontchain.length){
						frontchain.frontvalue = frontchain[frontchain.frontindex-1].p2.x;
					}
					else{
						frontchain.frontvalue = frontchain[frontchain.frontindex].p1.x;
					}
					//reposition(activechains);
					// there is a bug with the reposition code, resorting seems to work for now.
					// we really only need to reposition the left-most chain instead of sorting the whole list
					//activechains.sortOn("frontvalue", Array.NUMERIC);

					// "after" line passes through the selected vertex
					if(frontchain.frontindex == 1){
						sweepchains.push(frontchain);
					}

					//addChild(addDot(frontchain[frontchain.frontindex].p1));

					seg1 = frontchain[frontchain.frontindex-1];
					//this.parent.addChild(addDot(seg1.p1));
					previntersect = false;
					//for(var i:int=0; i<sweepchains.length; i++){
					for each(var schain:MonotoneChain in sweepchains){
						//var schain:MonotoneChain = sweepchains[i];

						if(schain.frontindex-1 < schain.length){
							seg2 = schain[schain.frontindex-1];
							if(seg2 == null){
								continue;
							}
							ip = null;
							var p:Point = null;

							if(schain != frontchain){
								if(seg1 is CircularArc && seg2 is CircularArc){
									ip = arcArcIntersect(seg1, seg2);
								}
								else if(!(seg1 is CircularArc) && seg2 is CircularArc){
									ip = lineArcIntersect(seg1,seg2);
								}
								else if(seg1 is CircularArc && !(seg2 is CircularArc)){
									ip = lineArcIntersect(seg2,seg1);
								}
								else{
									p = Global.lineIntersect(seg2.p1, seg2.p2, seg1.p1, seg1.p2, true);
								}

								if(ip != null && ip.length == 1){
									p = ip[0];
								}
								else if(ip != null && ip.length == 2){
									intersections.push(ip[0]);
									intersections.push(ip[1]);
								}

								// eliminate intersections caused by incident starting points (warning: error here will cause infinite subdivision!)

								var skip1:Boolean = false;
								var skip2:Boolean = false;

								var s1a:Boolean = false;
								var s1b:Boolean = false;

								var s2a:Boolean = false;
								var s2b:Boolean = false;

								// skip splitting the segment if the intersection point happens to fall close to an end point of that segment
								if(p != null && (seg1.p1 == seg2.p1 || seg1.p1 == seg2.p2 || seg1.p2 == seg2.p2 || seg1.p2 == seg2.p1)){
									if(Global.withinTolerance(seg1.p1, p, 0.1)){
										skip1 = true;
										s1a = true;
										p = seg1.p1;
									}
									else if(Global.withinTolerance(seg1.p2, p, 0.1)){
										skip1 = true;
										s1b = true;
										p = seg1.p2;
									}
									if(Global.withinTolerance(seg2.p1, p, 0.1)){
										skip2 = true;
										s2a = true;
										p = seg2.p1;
									}
									else if(Global.withinTolerance(seg2.p2, p, 0.1)){
										skip2 = true;
										s2b = true;
										p = seg2.p2;
									}

									// if the intersection points already coincide, we must merge the intersection points of the two intersecting segments
									if(skip1 && skip2){
										if(s1a && s2a){
											seg1.p1 = p;
											seg2.p1 = p;
										}
										else if(s1a && s2b){
											seg1.p1 = p;
											seg2.p2 = p;
										}
										else if(s1b && s2a){
											seg1.p2 = p;
											seg2.p1 = p;
										}
										else if(s1b && s2b){
											seg1.p2 = p;
											seg2.p2 = p;
										}
									}
								}
								else if(ip != null && ip.length == 2 && (seg1.p1 == seg2.p1 || seg1.p1 == seg2.p2 || seg1.p2 == seg2.p2 || seg1.p2 == seg2.p1)){
									// segments joined at one point can only have one additional intersection, only one of the returned values are valid
									/*if(Global.withinTolerance(seg1.p1, ip[0], 0.1)){
										//skip1 = true;
										ip[0] = seg1.p1;
									}
									else if(Global.withinTolerance(seg1.p2, ip[0], 0.1)){
										//skip1 = true;
										ip[0] = seg1.p2;
									}
									if(Global.withinTolerance(seg2.p1, ip[0], 0.1)){
										//skip2 = true;
										ip[0] = seg2.p1;
									}
									else if(Global.withinTolerance(seg2.p2, ip[0], 0.1)){
										//skip2 = true;
										ip[0] = seg2.p2;
									}

									if(Global.withinTolerance(seg1.p1, ip[1], 0.1)){
										ip[1] = seg1.p1;
									}
									else if(Global.withinTolerance(seg1.p2, ip[1], 0.1)){
										//skip1 = true;
										ip[1] = seg1.p2;
									}
									if(Global.withinTolerance(seg2.p1, ip[1], 0.1)){
										//skip2 = true;
										ip[1] = seg2.p1;
									}
									else if(Global.withinTolerance(seg2.p2, ip[1], 0.1)){
										//skip2 = true;
										ip[1] = seg2.p2;
									}*/


									if(Global.withinTolerance(seg1.p1, ip[0], 0.1) || Global.withinTolerance(seg1.p2, ip[0], 0.1) || Global.withinTolerance(seg2.p1, ip[0], 0.1) || Global.withinTolerance(seg2.p2, ip[0], 0.1)){
										ip[0] = null;
									}
									if(Global.withinTolerance(seg1.p1, ip[1], 0.1) || Global.withinTolerance(seg1.p2, ip[1], 0.1) || Global.withinTolerance(seg2.p1, ip[1], 0.1) || Global.withinTolerance(seg2.p2, ip[1], 0.1)){
										ip[1] = null;
									}

									if(ip[0] != null && ip[1] == null){
										p = ip[0];
									}
									else if(ip[1] != null && ip[0] == null){
										p = ip[1];
									}
									else if(ip[0] == null && ip[1] == null){
										p = null;
									}
								}
								/*else if(ip != null && ip.length == 2){
									trace("hummmmm..");
								}*/

								/*if(p != null && (seg1.p2 == seg2.p2 || seg1.p2 == seg2.p1)){
									if(Global.withinTolerance(seg1.p2, p)){
										skip2 = true;
									}
								}*/

								if(p != null){
									//this.parent.parent.addChild(addDot(p));
									if(!skip1 || !skip2){
										intersections.push(p);
										previntersect = true;
									}

									if(skip1 == false){
										if(seg1 is CircularArc){
											newarc1 = new CircularArc(seg1.p1,p,seg1.center,seg1.radius);
											newarc2 = new CircularArc(p,seg1.p2,seg1.center,seg1.radius);
											frontchain.splice(frontchain.frontindex-1,1,newarc1,newarc2);
											seg1 = newarc1;
										}
										else{
											newsegment1 = new Segment(seg1.p1,p);
											newsegment2 = new Segment(p,seg1.p2);
											frontchain.splice(frontchain.frontindex-1,1,newsegment1,newsegment2);
											seg1 = newsegment1;
										}

										frontchain.frontvalue = p.x;
										//frontchain.frontindex--;
									}

									//seg1.p2 = p;
									//frontchain[frontchain.frontindex-1].p2 = p;

									//frontchain.frontvalue = frontchain[frontchain.frontindex].p1.x;
									if(skip2 == false){
										if(seg2 is CircularArc){
											newarc1 = new CircularArc(seg2.p1, p,seg2.center,seg2.radius);
											newarc2 = new CircularArc(p, seg2.p2,seg2.center,seg2.radius);
											schain.splice(schain.frontindex-1,1,newarc1,newarc2);
										}
										else{
											newsegment1 = new Segment(seg2.p1,p);
											newsegment2 = new Segment(p,seg2.p2);
											schain.splice(schain.frontindex-1,1,newsegment1,newsegment2);
										}

										schain.frontvalue = p.x;
										//schain.frontindex--;
									}

									//schain[schain.frontindex-1].p2 = p;
									//seg2.p2 = p;
									//schain.frontvalue = schain[schain.frontindex].p1.x;

									//activechains.sortOn("frontvalue", Array.NUMERIC);
									//i--;
								}
								// if there are two valid intersection points, we need to split each segment into 3 pieces
								else if(ip != null && ip.length == 2 && ip[0] != null && ip[1] != null){
									// special case - very rarely, an intersection occurs between two arcs a line and an arc that has two valid intersection points
									intersections = intersections.concat(ip);
									previntersect = true;

									if(seg1 is CircularArc){
										newarc1 = new CircularArc(seg1.p1,ip[0],seg1.center,seg1.radius);
										newarc2 = new CircularArc(ip[0],ip[1],seg1.center,seg1.radius);
										newarc3 = new CircularArc(ip[1],seg1.p2,seg1.center,seg1.radius);

										frontchain.splice(frontchain.frontindex-1,1,newarc1,newarc2,newarc3);
										seg1 = newarc1;
									}
									else{
										newsegment1 = new Segment(seg1.p1,ip[0]);
										newsegment2 = new Segment(ip[0],ip[1]);
										newsegment3 = new Segment(ip[1],seg1.p2);

										frontchain.splice(frontchain.frontindex-1,1,newsegment1,newsegment2,newsegment3);
										seg1 = newsegment1;
									}

									frontchain.frontvalue = ip[0].x;

									if(seg2 is CircularArc){
										newarc1 = new CircularArc(seg2.p1,ip[0],seg2.center,seg2.radius);
										newarc2 = new CircularArc(ip[0], ip[1],seg2.center,seg2.radius);
										newarc3 = new CircularArc(ip[1], seg2.p2,seg2.center,seg2.radius);
										schain.splice(schain.frontindex-1,1,newarc1,newarc2,newarc3);
									}
									else{
										newsegment1 = new Segment(seg2.p1,ip[0]);
										newsegment2 = new Segment(ip[0],ip[1]);
										newsegment3 = new Segment(ip[1],seg2.p2);
										schain.splice(schain.frontindex-1,1,newsegment1,newsegment2,newsegment3);
									}

									schain.frontvalue = ip[0].x;
								}
							}
						}
						else{
							sweepchains.splice(sweepchains.indexOf(schain),1);
						}
					}

					// the front (left-most) chain may have changed after intersecting
					activechains.sortOn("frontvalue", Array.NUMERIC);
					/*if(collision == true){
						frontchain.frontindex--;
					}*/
				}
				else{
					activechains.shift();
					sweepchains.splice(sweepchains.indexOf(frontchain),1);
				}
			}
			/*
			for each(var point:Point in intersections){
				var dot:Dot = new Dot();
				dot.setInactive();
				dot.x = point.x*Global.zoom;
				dot.y = -point.y*Global.zoom;
				this.parent.addChild(dot);
			}*/

			// seglist now contains a list of segments, in original order
			var newseglist:Array = new Array();

			for each(chain in chains){
				// revert reversed chains to original order
				if(chain.reversed == true){
					for(i=0; i<chain.length; i++){
						var n:String = chain[i].name;
						chain[i] = chain[i].reverse();
						chain[i].name = n;
					}
					chain.reverse();
					chain.reversed = false;
				}
				newseglist = newseglist.concat(chain);
			}

			seglist = newseglist;

			if(trim == true){
				// trim off odd/even intervals

				// IMPORTANT: this method only works for local loops in the boundary curve (bounded by a single point)
				// it will not work with global invalid loops bounded by two intersection points
				// it also assumes that the first point is not in an invalid loop. Area for future improvement!

				var odd:Boolean = true; // odd intervals are valid if true (an interval is a group of segments between intersection points)

				var interval:Boolean = true; // the current interval (true = odd, false = even)

				for(i=0;i<seglist.length; i++){
					var seg:Segment = seglist[i];

					if(intersections.indexOf(seg.p1) != -1){
						interval = !interval;
					}

					if(odd != interval){
						//addChild(addDot(seg.p1));
						seglist.splice(i,1);
						i--;
					}
				}
			}
		}

		protected function reposition(activechains:Array):void{
			// repositions the first element of activechains
			var frontchain:MonotoneChain = activechains.shift();
			for(var i:int=0; i<activechains.length; i++){
				if(frontchain.frontvalue > activechains[i].frontvalue){
					activechains.splice(i+1,0,frontchain);
					return;
				}
			}
			activechains.splice(0,0,frontchain);
		}

		protected function removeInvalid(factor:Number){
			var len:int = seglist.length;

			var p1:Point;
			var p2:Point;

			var p3:Point;

			var origin:Point = new Point(0,0);

			for(var i:int=0; i<len; i++){
				p1 = new Point(seglist[i].p1.x*factor, -seglist[i].p1.y*factor);
				p2 = new Point(seglist[i].p2.x*factor, -seglist[i].p2.y*factor);

				p1 = trans.transformPoint(p1);
				p2 = trans.transformPoint(p2);

				fillmap.setPixel(p1.x,p1.y,0xFF0000);

				var dot:Dot;

				if(fillmap.hitTest(origin,0xAA,p1) || fillmap.hitTest(origin,0xAA,p2)){
				//if(this.hitTestPoint(p1.x,p1.y, true) || this.hitTestPoint(p2.x,p2.y, true)){
					seglist[i].name = "invalid";
					/*dot = new Dot();
					dot.x = seglist[i].p1.x*factor;
					dot.y = -seglist[i].p1.y*factor;
					addChild(dot);*/
					//addChild(addDot(seglist[i].p1));
				}
				else{
					p3 = getMid(seglist[i]);
					p3.y = -p3.y;
					p3.x *= factor;
					p3.y *= factor;

					p3 = trans.transformPoint(p3);

					if(fillmap.hitTest(origin,0xAA,p3)){
						seglist[i].name = "invalid";
						//addChild(addDot(p3));
					}
				}
			}

			for(i=0; i<seglist.length; i++){
				if(seglist[i].name == "invalid"){
					//addChild(addDot(seglist[i].p1));
					//addChild(addDot(seglist[i].p2));
					seglist.splice(i,1);
					i--;
				}
			}

			fillmap.dispose();
			fillmap = null;
		}

		protected function getMid(segment:*):Point{
			var mid:Point;

			if(segment is CircularArc){
				var arc:CircularArc = segment as CircularArc;

				var diff:Number = Global.getAngle(new Point(arc.p1.x-arc.center.x,arc.p1.y-arc.center.y), new Point(arc.p2.x-arc.center.x,arc.p2.y-arc.center.y));
				var angle:Number = Math.atan2(arc.p1.y-arc.center.y,arc.p1.x-arc.center.x);

				angle += 0.5*diff;

				var normx:Number = Math.abs(arc.radius)*Math.cos(angle);
				var normy:Number = Math.abs(arc.radius)*Math.sin(angle);

				mid = new Point(arc.center.x+normx, arc.center.y+normy);
			}
			else{
				var seg:Segment = segment as Segment;
				mid = new Point(0.5*(seg.p1.x+seg.p2.x),0.5*(seg.p1.y+seg.p2.y));
			}

			return mid;
		}

		// finds loops in the offset curve and returns them in an array of cutpaths
		protected function processLoops():Array{
			var newseglist:Array = seglist.slice();

			if(seglist.length < 2){
				return new Array();
			}

			var processedloops:Array = new Array();

			var origin:Segment;
			var loop:Array;

			// loops under this area limit will be removed
			//var arealimit:Number = 0.0000015;
			var arealimit:Number = 0.000015;

			if(Global.unit == "cm"){
				arealimit *= 2.54*2.54;
			}

			var minarea:Number = 0;

			while(seglist.length > 0){
				//addChild(addDot(seglist[0].p1));

				// the loop detection algorithm depends on the starting point being on the path of interest
				// the stray "stubble" segments are mostly very short, so we start on the longest possible segment
				// to guarantee that the segment is on the path of interest
				origin = getLongest();

				for each(var seg in seglist){
					seg.active = false;
				}


				loop = branchNext(origin,origin);
				if(loop.length > 1){
					loop.pop();

					for each(var l in loop){
						var index:int = seglist.indexOf(l);
						if(index != -1){
							seglist.splice(index,1);
						}
					}

					// remove small tangential loops
					// note: in certain rare situations (multiple intersecting loops that are valid and returned as a single loop) this function is prone to removing valid loops, consider revising
					// note2: actually this happens quite often.. important area of optimization!
					for(var i:int=0; i<loop.length; i++){
						var p:Point = loop[i].p2;
						// search previous 5 segments for loop
						for(var j:int=Math.max(0,i-5); j<i; j++){
							if(p == loop[j].p1 && j != 0 && i != loop.length){
								loop.splice(j,i-j+1);
								i = j;
								break;
							}
						}
					}

					if(loop.length < 2 || loop[0].p1 != loop[loop.length-1].p2){
						continue;
					}

					var area:Number = getPolygonArea(loop);

					if(area < minarea){
						minarea = area;
					}

					//trace("total area: ",area);
					if(Math.abs(area) > arealimit){
						// wrap the loops in a cutpath and return them
						var cutpath:CutPath = new CutPath();
						cutpath.addSegments(loop);
						processedloops.push(cutpath);
					}
				}
				else{
					seglist.splice(seglist.indexOf(origin),1);
					/*loop = new Array();
					for(var i:int=0; i<seglist.length; i++){
						//if(seglist[i].active == true){
							loop.push(seglist[i]);
							seglist.splice(i,1);
							i--;
						//}
					}
					var cutpath:CutPath = new CutPath();
					cutpath.addSegments(loop);
					processedloops.push(cutpath);*/
				}
			}

			// there must be at least one counterclockwise loop generated
			if(minarea >= 0){
				return new Array();
			}

			/*if(processedloops.length == 0){
				this.parent.parent.addChild(fillbitmap);
			}*/

			return processedloops;
		}

		protected function getLongest():Segment{
			var longest:Segment = seglist[0];

			var len:int = seglist.length;

			var dis:Number;
			var maxdis:Number = Math.pow(seglist[0].p1.x - seglist[0].p2.x,2) + Math.pow(seglist[0].p1.y - seglist[0].p2.y,2);

			for(var i:int=0; i<len; i++){
				dis = Math.pow(seglist[i].p1.x - seglist[i].p2.x,2) + Math.pow(seglist[i].p1.y - seglist[i].p2.y,2);
				if(dis > maxdis){
					maxdis = dis;
					longest = seglist[i];
				}
			}

			return longest;
		}

		// start at the given node and find a loop that goes back to the origin
		protected function branchNext(current:Segment, origin:Segment):Array{
			var loop:Array = new Array(current);

			// get a list of all segments that are attached to the current segment
			var nextarray:Array = getNext(current);

			var index:int;

			// if only one candidate for loop processing, just add it to the loop
			while(nextarray.length == 1){
				loop.push(nextarray[0]);
				nextarray[0].active = true;
				if(nextarray[0] == origin){
					// success! found loop
					return loop;
				}

				// every time we push something on to loop, remove it from the seglist
				// this prevents the same segment from being traversed recursively
				/*index = seglist.indexOf(nextarray[0]);
				if(index != -1){
					seglist.splice(index,1);
				}*/

				current = nextarray[0];
				nextarray = getNext(current);
			}

			// if multiple candidates exist (braches out from current node), recursively investigate each branch
			for each(var n in nextarray){
				n.active = true;

				if(n == origin){
					// success! found loop
					loop.push(origin);
					return loop;
				}

				/*index = seglist.indexOf(n);
				if(index != -1){
					seglist.splice(index,1);
				}*/

				var recursloop:Array = branchNext(n, origin);

				if(recursloop.length > 0){
					if(recursloop[recursloop.length-1] == origin){
						//recursloop.pop();
						loop = loop.concat(recursloop);

						/*for each(var segment in recursloop){
							seglist.splice(seglist.indexOf(segment),1);
						}*/

						return loop;
					}
				}
			}

			// if nextarray is empty, we've reached a dead end. No loop exists
			return new Array();
		}

		protected function getNext(current:Segment):Array{
			var nextarray:Array = new Array();

			var seg:*;

			for(var i:int=0; i<seglist.length; i++){
				seg = seglist[i];
				if(seg != current && seg.active == false){
					if(seg.p1 == current.p2){
						nextarray.push(seg);
					}
				}
			}

			return nextarray;
		}

		// finds the intersection between a line segment and a circular arc
		// returned array may be empty, contain one point, or two points
		// if segment = false, an infinite line is used
		protected function lineArcIntersect(seg:Segment, arc:CircularArc, segment:Boolean = true):Array{

			// first do line-circle intersection, then figure out if the resulting points lie on the arc
			var A:Number = Math.pow(seg.p2.x - seg.p1.x, 2) + Math.pow(seg.p2.y - seg.p1.y, 2);
			var B:Number = 2*(seg.p2.x - seg.p1.x)*(seg.p1.x - arc.center.x) + 2*(seg.p2.y - seg.p1.y)*(seg.p1.y - arc.center.y);
			var C:Number = Math.pow(seg.p1.x - arc.center.x, 2) + Math.pow(seg.p1.y - arc.center.y, 2) - (arc.radius*arc.radius);

			// solve the quadratic formula for t
			var discriminant:Number = Math.pow(B,2) - 4*A*C;

			if(discriminant < 0){
				return null;
			}

			discriminant = Math.sqrt(discriminant);

			var t1:Number;
			var t2:Number;

			t1 = (0.5*(-B + discriminant))/A;
			t2 = (0.5*(-B - discriminant))/A;

			var ip1:Point;
			var ip2:Point;

			if(segment && (t1 <= 0 || t1 >= 1) && (t2 <= 0 || t2 >= 1)){
				return null;
			}

			if(!segment || (segment && t1 > 0 && t1 < 1)){
				ip1 = new Point();

				ip1.x = seg.p1.x + (seg.p2.x - seg.p1.x)*t1;
				ip1.y = seg.p1.y + (seg.p2.y - seg.p1.y)*t1;
			}

			if(!segment || (segment && t2 > 0 && t2 < 1)){
				ip2 = new Point();

				ip2.x = seg.p1.x + (seg.p2.x - seg.p1.x)*t2;
				ip2.y = seg.p1.y + (seg.p2.y - seg.p1.y)*t2;
			}

			// check whether the intersection point lies on the arc as well
			if(ip1 != null && !arc.onArc(ip1)){
				ip1 = null;
			}

			if(ip2 != null && !arc.onArc(ip2)){
				ip2 = null;
			}

			if(!ip1 && !ip2){
				return null;
			}
			else if(ip1 && !ip2){
				return new Array(ip1);
			}
			else if(ip2 && !ip1){
				return new Array(ip2);
			}
			else if(ip1.equals(ip2)){
				return new Array(ip1);
			}
			else{
				var returnarray:Array;
				if(ip1.x < ip2.x){
					returnarray = new Array(ip1,ip2);
				}
				else{
					returnarray = new Array(ip2,ip1);
				}
				return returnarray;
			}
		}

		/*protected function arcArcIntersect(arc1:CircularArc, arc2:CircularArc):Array{
			var u:Number = Math.pow(arc1.radius,2) - Math.pow(arc2.radius,2) + Math.pow(arc1.center.x,2) + Math.pow(arc2.center.x,2) - 2*arc1.center.x*arc2.center.x - Math.pow(arc1.center.y,2) + Math.pow(arc2.center.y,2);
			var v:Number = arc2.center.x - arc1.center.x;
			var w:Number = arc1.center.y - arc2.center.y;

			var a:Number = 4*(Math.pow(w,2)+Math.pow(v,2));
			var b:Number = 4*(u*w - 2*Math.pow(v,2)*arc1.center.y);
			var c:Number = Math.pow(u,2) - 4*Math.pow(v,2)*(Math.pow(arc1.radius,2) - Math.pow(arc1.center.y,2));

			var d:Number;
			var e:Number;

			var ip1:Point;
			var ip2:Point;

			var discriminant:Number = Math.pow(b,2) - 4*a*c;

			if(discriminant < 0){
				return null;
			}

			discriminant = Math.sqrt(discriminant);

			// first point
			ip1 = new Point();

			ip1.y = (0.5*(-b + discriminant))/a;

			d = Math.pow(ip1.y-arc1.center.y,2) - Math.pow(arc1.radius,2);
			e = Math.pow(ip1.y - arc2.center.y,2) - Math.pow(arc2.radius,2);

			ip1.x = (0.5*(Math.pow(arc2.center.x,2)-Math.pow(arc1.center.x,2)-d+e))/v;

			// second point
			ip2 = new Point();

			ip2.y = (0.5*(-b - discriminant))/a;

			d = Math.pow(ip2.y-arc1.center.y,2) - Math.pow(arc1.radius,2);
			e = Math.pow(ip2.y - arc2.center.y,2) - Math.pow(arc2.radius,2);

			ip2.x = (0.5*(Math.pow(arc2.center.x,2)-Math.pow(arc1.center.x,2)-d+e))/v;

			if(isNaN(ip1.x) || isNaN(ip1.y)){
				ip1 = null;
			}

			if(isNaN(ip2.x) || isNaN(ip2.y)){
				ip2 = null;
			}

			// check whether the intersection point lies on both arcs
			if(ip1 != null && (!onArc(ip1, arc1) || !onArc(ip1, arc2))){
				ip1 = null;
			}

			if(ip2 != null && (!onArc(ip2, arc1) || !onArc(ip2, arc2))){
				ip2 = null;
			}

			if(!ip1 && !ip2){
				return null;
			}
			else if(ip1 && !ip2){
				return new Array(ip1);
			}
			else if(ip2 && !ip1){
				return new Array(ip2);
			}
			else if(ip1.equals(ip2)){
				return new Array(ip1);
			}
			else{
				var returnarray:Array;
				if(ip1.x < ip2.x){
					returnarray = new Array(ip1,ip2);
				}
				else{
					returnarray = new Array(ip2,ip1);
				}
				return returnarray;
			}
		}*/

		// returns the intersection points of two circular arcs
		// returned array may be empty, contain 1 point, or two points
		protected function arcArcIntersect(arc1:CircularArc, arc2:CircularArc):Array{
			var d2:Number = Math.pow(arc1.center.x-arc2.center.x,2) + Math.pow(arc1.center.y-arc2.center.y,2);
			var d:Number = Math.sqrt(d2);

			if(d > Math.abs(arc1.radius) + Math.abs(arc2.radius)){
				return null;
			}
			if(d < Math.abs(Math.abs(arc1.radius) - Math.abs(arc2.radius))){
				return null;
			}

			var a:Number = (Math.pow(arc1.radius,2) - Math.pow(arc2.radius,2) + d2)/(2*d);
			var h:Number = Math.sqrt(Math.pow(arc1.radius,2)-Math.pow(a,2));

			var mid:Point = new Point();

			mid.x = arc1.center.x + a*(arc2.center.x - arc1.center.x)/d;
			mid.y = arc1.center.y + a*(arc2.center.y - arc1.center.y)/d;

			var ip1:Point = new Point();
			var ip2:Point = new Point();

			ip1.x = mid.x + h*(arc2.center.y-arc1.center.y)/d;
			ip1.y = mid.y - h*(arc2.center.x-arc1.center.x)/d;

			ip2.x = mid.x - h*(arc2.center.y-arc1.center.y)/d;
			ip2.y = mid.y + h*(arc2.center.x-arc1.center.x)/d;

			if(isNaN(ip1.x) || isNaN(ip1.y)){
				ip1 = null;
			}

			if(isNaN(ip2.x) || isNaN(ip2.y)){
				ip2 = null;
			}

			// check whether the intersection point lies on both arcs
			if(ip1 != null && (!arc1.onArc(ip1) || !arc2.onArc(ip1))){
				ip1 = null;
			}

			if(ip2 != null && (!arc1.onArc(ip2) || !arc2.onArc(ip2))){
				ip2 = null;
			}

			if(!ip1 && !ip2){
				return null;
			}
			else if(ip1 && !ip2){
				return new Array(ip1);
			}
			else if(ip2 && !ip1){
				return new Array(ip2);
			}
			else if(ip1.equals(ip2)){
				return new Array(ip1);
			}
			else{
				var returnarray:Array;
				if(ip1.x < ip2.x){
					returnarray = new Array(ip1,ip2);
				}
				else{
					returnarray = new Array(ip2,ip1);
				}
				return returnarray;
			}
		}

		// nests all children paths in contour order (a cutpath is a child of another cutpath if its topologically "inside" it)
		/*public function nestPaths():void{
			var cutlist:Array = new Array();

			var child:DisplayObject;

			for(var i:int=0; i<numChildren; i++){
				child = getChildAt(i);
				if(child is CutPath){
					// we use an object instead of pushing the cutpath directly, this is because we need to maintain a parent/child relationship without using the as3 displaylist
					cutlist.push({cutpath: child, children: new Array()});
				}
			}

			var resolution:Number = 300;

			if(Global.unit == "cm"){
				resolution /= 2.54;
			}

			var cutpath:CutPath;
			var obj:Object;
			var objlist:Array = new Array();

			while(cutlist.length > 0){
				obj = cutlist.shift();
				for(i=0; i<cutlist.length; i++){
					// test for intersection at 300 pixels per inch, if intersection occurs, do nothing
					// always returns false, need to fix!
					if(HitTest.complexHitTestObject(obj.cutpath, cutlist[i].cutpath)){
						continue;
					}

					// if they do not intersect, check whether they are inside one another (if they do not intersect, either all points are inside or all points are outside)
					if(obj.cutpath.containsPoint(cutlist[i].cutpath.seglist[0].p1)){
						obj.children.push(cutlist[i].cutpath);
						cutlist.splice(i,1);
						i--;
					}
					else if(cutlist[i].cutpath.containsPoint(obj.cutpath.seglist[0].p1)){
						cutlist[i].children.push(obj.cutpath);
						break;
					}
				}

				objlist.push(obj);
			}

			for each(obj in objlist){
				for each(cutpath in obj.children){
					obj.cutpath.addChild(cutpath);
				}
			}

			// nest child paths
			for(i=0; i<numChildren; i++){
				child = getChildAt(i);
				if(child is CutPath){
					cutpath = child as CutPath;
					cutpath.nestPaths();
				}
			}
		}*/

		public function nestPaths():void{
			var cutlist:Array = new Array();

			var child:DisplayObject;
			var cutpath:CutPath;

			for(var i:int=0; i<numChildren; i++){
				child = getChildAt(i);
				if(child is CutPath){
					// we use an object instead of pushing the cutpath directly, this is because we need to maintain a parent/child relationship without using the as3 displaylist
					cutlist.push(child);
				}
			}

			for(i=0; i<cutlist.length; i++){
				cutpath = cutlist[i];
				for(var j:int=0; j<cutlist.length; j++){
					if(cutpath != cutlist[j]){
					// check whether they are inside one another (if they do not intersect, either all points are inside or all points are outside)
						if(cutpath.containsPoint(cutlist[j].seglist[0].p1)){
							cutpath.addChild(cutlist[j]);
							cutlist.splice(j,1);
							j--;
						}
						else if(cutlist[j].containsPoint(cutpath.seglist[0].p1)){
							cutlist[j].addChild(cutpath);
						}
					}
				}
			}

			// nest child paths
			for(i=0; i<numChildren; i++){
				child = getChildAt(i);
				if(child is CutPath){
					cutpath = child as CutPath;
					cutpath.nestPaths();
				}
			}
		}

		// horizontal raycast point-in-polygon method for determining whether the given point is inside the current contour
		public function containsPoint(point:Point):Boolean{
			var intersections:Array = new Array();

			var ylevel:Number = point.y;
			var v1:Point = new Point(0,ylevel);
			var v2:Point = new Point(1,ylevel);

			var hsegment:Segment = new Segment(v1,v2);

			for each(var seg:Segment in seglist){
				if((seg.p1.y > ylevel && seg.p2.y < ylevel) || (seg.p1.y < ylevel && seg.p2.y > ylevel)){
					if(seg is CircularArc){
						var arc:CircularArc = seg as CircularArc;
						var points:Array = lineArcIntersect(hsegment, arc, false);
						if(points != null){
							if(points[0]){
								intersections.push(points[0].x);
							}
							if(points[1]){
								intersections.push(points[1].x);
							}
						}
					}
					else{
						var ip:Point = Global.lineIntersect(seg.p1,seg.p2,v1,v2,false);
						if(ip != null){
							intersections.push(ip.x);
						}
					}
				}
				// this is the corner case where the point is lying on top of a horizontal line (happens quite often)
				else if(!(seg is CircularArc) && seg.p1.y == ylevel && seg.p2.y == ylevel){
					//intersections.push(0.5*(seg.p1.x+seg.p2.x));
					intersections.push(seg.p1.x);
					intersections.push(seg.p2.x);
				}
				else if(seg is CircularArc && seg.p1.y == ylevel && seg.p2.y == ylevel){
					intersections.push(seg.p1.x);
					intersections.push(seg.p2.x);
				}
			}

			intersections.sort(Array.NUMERIC);

			var odd:Boolean = true;

			for(var i:int=0; i<intersections.length; i++){
				odd = !odd;
				if(point.x < intersections[i]){
					return odd;
				}
			}

			return false;
		}

		// set the winding of each child path. Odd Children (curve boundaries) will be wound in the given direction, and even children (islands) will be wound in the opposite direction
		public function setChildrenDirection(dir:int):void{
			var child:DisplayObject;
			var cutpath:CutPath;

			for(var i:int=0; i<numChildren; i++){
				child = getChildAt(i);
				if(child is CutPath){
					cutpath = child as CutPath;
					cutpath.setDirection(dir);
					if(dir == 1){
						cutpath.setChildrenDirection(2);
					}
					else{
						cutpath.setChildrenDirection(1);
					}
				}
			}
		}

		// recusive tree-walk (Depth-order) of all child nodes. Cuts will be made in returned order
		public function getChildren():Array{
			var returnarray:Array = new Array();
			var cutpath:CutPath;

			for(var i:int=0; i<numChildren; i++){
				cutpath = getChildAt(i) as CutPath;
				if(cutpath != null){
					var childarray:Array = cutpath.getChildren();
					returnarray = returnarray.concat(childarray);

					returnarray.push(cutpath);
				}
			}

			return returnarray;
		}

		// returns the number of children that are cutpaths
		public function getNumChildren():int{
			var children:int = 0;
			var cutpath:CutPath;
			for(var i:int=0; i<numChildren; i++){
				cutpath = getChildAt(i) as CutPath;
				if(cutpath != null){
					children++;
				}
			}

			return children;
		}

		// successively set the starting segment for each child cutpath
		// this is necessary because the starting point was rotated to be the largest segment for loop processing, which doesn't work for machining
		public function rotateChildren():void{

			var children:Array = getChildren();

			if(children.length == 0){
				return;
			}

			// rotation should start from outside-in
			//children.reverse();

			var cutpath:CutPath;

			var prev:CutPath = children[0];

			for(var i:int=1; i<children.length; i++){
				cutpath = children[i];
				if(cutpath != null){
					var depthdiff:int = cutpath.pocketdepth - prev.pocketdepth;

					if(prev != cutpath && (depthdiff == -1 || depthdiff == 1) && (prev.parent == cutpath || cutpath.parent == prev)){
						cutpath.setStart(prev.seglist[0].p1);
					}

					prev = cutpath;
				}
			}
		}

		// set the starting segment such that it is closest to the given point p
		public function setStart(p:Point):void{
			var closest:int = 0;
			var mindis:Number = Math.pow(seglist[0].p1.x-p.x,2) + Math.pow(seglist[0].p1.y-p.y,2);
			var d2:Number;

			for(var i:int=0; i<seglist.length; i++){
				d2 = Math.pow(seglist[i].p1.x-p.x,2) + Math.pow(seglist[i].p1.y-p.y,2);
				if(d2<mindis){
					mindis = d2;
					closest = i;
				}
			}

			var newseglist1:Array = seglist.slice(closest);
			var newseglist2:Array = seglist.slice(0,closest);

			seglist = newseglist1.concat(newseglist2);
		}

		public function drawStartArrow():void{
			graphics.clear();
			drawArrow(seglist[0], 5);
		}

		public function drawArrows(size:int):void{
			graphics.clear();
			for each(var seg:Segment in seglist){
				drawArrow(seg, size);
			}
		}

		// draw a little arrow to indicate the winding direction of this cutpath
		public function drawArrow(seg:*, size:int):void{
			var normal:Point;
			var tangent:Point;

			var angle:Number;

			if(!seg || !seg.p1 || !seg.p2){
				return;
			}

			if(seg is CircularArc){
				angle = Global.getAngle(new Point(seg.p1.x-seg.center.x,seg.p1.y-seg.center.y),new Point(seg.p2.x-seg.center.x,seg.p2.y-seg.center.y));
				if(angle > 0){
					normal = new Point(seg.p1.x-seg.center.x,seg.p1.y-seg.center.y);
				}
				else{
					normal = new Point(-seg.p1.x+seg.center.x,-seg.p1.y+seg.center.y);
				}
				tangent = new Point(-normal.y,normal.x);
			}
			else{
				tangent = new Point(seg.p2.x-seg.p1.x,seg.p2.y-seg.p1.y);
				normal = new Point(-tangent.y, tangent.x);
			}

			tangent.normalize(size);
			normal.normalize(size);

			var p1:Point = seg.p1.clone();
			p1.x *= Global.zoom;
			p1.y *= Global.zoom;

			p1 = p1.add(tangent);

			var p2:Point = seg.p1.clone();
			p2.x *= Global.zoom;
			p2.y *= Global.zoom;

			p2 = p2.add(normal);

			var p3:Point = seg.p1.clone();
			p3.x *= Global.zoom;
			p3.y *= Global.zoom;

			p3 = p3.subtract(normal);

			p1.y = -p1.y;
			p2.y = -p2.y;
			p3.y = -p3.y;

			graphics.lineStyle(1,0x009911,1,false,LineScaleMode.NONE);
			graphics.beginFill(0x009911);
			graphics.moveTo(p1.x,p1.y);
			graphics.lineTo(p2.x,p2.y);
			graphics.lineTo(p3.x,p3.y);
			graphics.lineTo(p1.x,p1.y);
			graphics.endFill();
		}

		// returns bounding rectangle in right-hand coordinates
		public function getExactBounds():Rectangle{
			var maxx:Number = seglist[0].p1.x;
			var maxy:Number = seglist[0].p1.y;

			var minx:Number = seglist[0].p1.x;
			var miny:Number = seglist[0].p1.y;

			for(var i:int=0; i<seglist.length; i++){
				var lmaxx:Number;
				var lmaxy:Number;
				var lminx:Number;
				var lminy:Number;

				if(seglist[i] is CircularArc){
					var rect:Rectangle = seglist[i].getExactBounds();
					lmaxx = rect.x + rect.width;
					lmaxy = rect.y + rect.height;
					lminx = rect.x;
					lminy = rect.y;
				}
				else{
					lmaxx = Math.max(seglist[i].p1.x, seglist[i].p2.x);
					lmaxy = Math.max(seglist[i].p1.y, seglist[i].p2.y);
					lminx = Math.min(seglist[i].p1.x, seglist[i].p2.x);
					lminy = Math.min(seglist[i].p1.y, seglist[i].p2.y);
				}

				if(lminx < minx){
					minx = lminx;
				}
				if(lminy < miny){
					miny = lminy;
				}
				if(lmaxx > maxx){
					maxx = lmaxx;
				}
				if(lmaxy > maxy){
					maxy = lmaxy;
				}
			}

			return new Rectangle(minx,miny,maxx-minx,maxy-miny);
		}

		public function getLength():Number{
			if(!seglist || seglist.length == 0){
				return 0;
			}

			var length:Number = 0;

			for(var i:int=0; i<seglist.length; i++){
				length += seglist[i].getLength();
			}

			return length;
		}

		// adds tabs based on given parameters and returns the number of tabs added
		public function addTabs(tabspacing:Number, tabwidth:Number, tabheight:Number, diameter:Number):int{
			var length:Number = getLength();

			if(!tabs){
				tabs = new Array();
			}

			var tabnum:int = Math.floor(length/tabspacing);
			for(var i:int = 0; i<tabnum; i++){
				if(i*tabspacing + tabwidth > length){
					break;
				}
				var tab:Tab = new Tab(i*tabspacing, tabwidth, tabheight, diameter);
				addTab(tab);
			}

			tabs.sortOn("location", Array.NUMERIC);

			return tabnum;
		}

		public function addTab(tab:Tab):void{
			tabs.push(tab);
			tab.addEventListener(MouseEvent.MOUSE_DOWN, tabDown);
		}

		private function tabDown(e:MouseEvent):void{
			for(var i:int=0; i<tabs.length; i++){
				tabs[i].setInactive();
			}

			var tab:Tab = e.target as Tab;

			tab.setActive();
			dragtab = tab;

			stage.addEventListener(MouseEvent.MOUSE_UP, tabUp);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, tabMove);

			Global.dragging = true;

			tabpositions = getTabPositions();

			e.stopPropagation();
		}

		private function tabUp(e:MouseEvent):void{
			Global.dragging = false;
			var tab:Tab = e.target as Tab;
			stage.removeEventListener(MouseEvent.MOUSE_UP, tabUp);
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, tabMove);

			tabs.sortOn("location",Array.NUMERIC);

			// detect and remove overlapping tabs
			for(var i:int=0; i<tabs.length; i++){
				if(tabs[i] != dragtab){
					if((tabs[i].location <= dragtab.location && dragtab.location < tabs[i].location + tabs[i].tabwidth) || (dragtab.location <= tabs[i].location && tabs[i].location < dragtab.location + dragtab.tabwidth)){
						//if(dragtab.location > tabs[i].location){
							var min:Number = Math.min(dragtab.location, tabs[i].location);
							var max:Number = Math.max(dragtab.location+dragtab.tabwidth, tabs[i].location+tabs[i].tabwidth);

							if(max > dragtab.location+dragtab.tabwidth){
								dragtab.tabwidth = max-min;
							}
							if(min < dragtab.location){
								dragtab.location = min;
								dragtab.x = tabs[i].x;
								dragtab.y = tabs[i].y;
								dragtab.rotation = tabs[i].rotation;
							}

							dragtab.redraw();
						//}
						if(contains(tabs[i])){
							removeChild(tabs[i]);
						}
						tabs.splice(i,1);
					}
				}
			}

			var length:Number = getLength();

			if(dragtab.location + dragtab.tabwidth > length){
				dragtab.location = length-dragtab.tabwidth;
			}

			tabpositions = null;
			dragtab = null;
		}

		private function tabMove(e:MouseEvent):void{
			var mousepoint:Point = new Point(this.mouseX/Global.zoom, -this.mouseY/Global.zoom);
			var tabobj:Object = getClosestPosition(mousepoint);

			dragtab.x = tabobj.point.x*Global.zoom;
			dragtab.y = -tabobj.point.y*Global.zoom;

			dragtab.rotation = tabobj.rotation;
			dragtab.location = tabobj.location - dragtab.tabwidth/2;

			if(dragtab.location < 0){
				dragtab.location += getLength();
			}
		}

		// returns a list of possible tab positions for tab dragging
		public function getTabPositions():Array{
			var positions:Array = new Array();

			var length:Number = getLength();

			// we want 1000 possible tab positions
			var increment:Number = length/1000;

			var current:Number = 0;

			var locus:Number = 0;

			for(var i:int=0; i<seglist.length; i++){
				var seglength:Number = seglist[i].getLength();

				while(positions.length < 1000){
					if(locus <= current && current < locus + seglength){
						var point:Point = seglist[i].getPointFromLength(current-locus);
						var normal:Point;
						if(seglist[i] is CircularArc){
							normal = new Point(point.x-seglist[i].center.x, point.y-seglist[i].center.y);
						}
						else{
							normal = seglist[i].getNormal();
						}

						var angle:Number = Math.atan2(-normal.y,normal.x);
						angle *= (180/Math.PI);

						var obj:Object = {location: current, point: point, rotation: angle};
						positions.push(obj);

						current += increment;
						continue;
					}
					break;
				}

				locus += seglength;
			}

			return positions;
		}

		public function getClosestPosition(p:Point):Object{
			if(!tabpositions || tabpositions.length == 0){
				return null;
			}

			var min:Number = Math.pow(tabpositions[0].point.x-p.x,2) + Math.pow(tabpositions[0].point.y-p.y,2);
			var minobj:Object = tabpositions[0];

			for(var i:int=0; i<tabpositions.length; i++){
				var dis2:Number = Math.pow(tabpositions[i].point.x-p.x,2) + Math.pow(tabpositions[i].point.y-p.y,2);
				if(dis2 < min){
					min = dis2;
					minobj = tabpositions[i];
				}
			}

			return minobj;
		}

		public function redrawTabs():void{
			if(!tabs || tabs.length == 0){
				return;
			}

			// go through segment list and position each tab
			var locus:Number = 0;

			var tablist:Array = tabs.slice();

			for(var i:int=0; i<seglist.length; i++){
				if(tablist.length == 0){
					break;
				}

				var seglength:Number = seglist[i].getLength();

				while(tablist.length > 0){
					var tab:Tab = tablist[0];
					var center:Number = tab.location + tab.tabwidth/2;

					if(locus <= center && center < locus + seglength){
						var point:Point = seglist[i].getPointFromLength(center-locus);
						var normal:Point;
						if(seglist[i] is CircularArc){
							normal = new Point(point.x-seglist[i].center.x, point.y-seglist[i].center.y);
						}
						else{
							normal = seglist[i].getNormal();
						}

						var angle:Number = Math.atan2(-normal.y,normal.x);
						angle *= (180/Math.PI);

						addChild(tab);
						tab.x = point.x*Global.zoom;
						tab.y = -point.y*Global.zoom;
						tab.rotation = angle;
						tab.redraw();

						tablist.shift();

						continue;
					}

					break;
				}

				locus += seglength;
			}
		}

		public function removeActiveTabs():void{
			if(!tabs || tabs.length == 0){
				return;
			}
			for(var i:int=0; i<tabs.length; i++){
				if(tabs[i].active == true){
					tabs[i].removeEventListener(MouseEvent.MOUSE_DOWN, tabDown);
					if(contains(tabs[i])){
						removeChild(tabs[i]);
					}
					tabs.splice(i,1);
					i--;
				}
			}
		}

		// returns a cutpath with splits at the beginning and end of each tab
		// note: not meant to be permanent! only used for post when doing tabs
		/*public function processTabs():CutPath{

			var newseglist:Array = seglist.slice();
			var locus:Number = 0;

			var tablist:Array = tabs.slice();

			for(var i:int=0; i<newseglist.length; i++){
				if(tablist.length == 0){
					break;
				}

				var seglength:Number = newseglist[i].getLength();

				var tab:Tab = tablist[0];

				//while(tablist.length > 0){
				var split:Array;
				var stay:Boolean = false;
				if(locus <= tab.location && tab.location < locus + seglength){
					if(locus == tab.location){
						tab.p1 = newseglist[i].p1;
						stay = true;
						//i--;
						//continue;
					}
					else{
						split = newseglist[i].splitByLength(tab.location-locus);
						tab.p1 = split[0].p2;
						newseglist.splice(i,1,split[0],split[1]);
						seglength = split[0].getLength();
						//locus += seglength;
						//continue;
					}
				}
				//if(!tab.p2){
					if(locus <= tab.location+tab.tabwidth && tab.location+tab.tabwidth < locus + seglength){
						if(locus == tab.location + tab.tabwidth){
							tab.p2 = newseglist[i].p1;
							tablist.shift();
							i--;
							continue;
						}
						else{
							split = newseglist[i].splitByLength(tab.location+tab.tabwidth-locus);
							tab.p2 = split[0].p2;
							newseglist.splice(i,1,split[0],split[1]);
							seglength = split[0].getLength();
							locus += seglength;

							tablist.shift();
							continue;
						}
						//tablist.shift();

						//continue;
					}
				//}
				//}
				//tablist.shift();
				if(stay){
					i--;
				}
				else{
					locus += seglength;
				}
			}

			var cutpath:CutPath = new CutPath();
			cutpath.seglist = newseglist;
			cutpath.tabs = tabs;

			return cutpath;
		}*/

		public function processTabs():CutPath{
			if(!tabs || tabs.length == 0){
				return this;
			}

			var newseglist:Array = seglist.slice();
			var locus:Number = 0;

			var tablist:Array = tabs.slice();
			var i:int=0;
			var current:int=0;

			while(tablist.length > 0){
				var tab:Tab = tablist.shift();

				var seglength:Number = 0;

				for(i=current; i<newseglist.length; i++){
					seglength = newseglist[i].getLength();
					if(locus <= tab.location && tab.location < locus + seglength){
						break;
					}
					locus += seglength;
				}

				current = i;

				if(current == newseglist.length){
					break;
				}

				var split:Array;

				//if(locus <= tab.location && tab.location < locus + seglength){
					if(locus == tab.location){
						tab.p1 = newseglist[current].p1;
						//i--;
						//continue;
					}
					else{
						split = newseglist[current].splitByLength(tab.location-locus);
						tab.p1 = split[0].p2;
						newseglist.splice(current,1,split[0],split[1]);
						//locus += seglength;
						//continue;
					}
				//}

				for(i=current; i<newseglist.length; i++){
					seglength = newseglist[i].getLength();
					if(locus <= tab.location+tab.tabwidth && tab.location+tab.tabwidth < locus + seglength){
						break;
					}
					locus += seglength;
				}

				current = i;

				if(current == newseglist.length){
					break;
				}

				if(locus == tab.location + tab.tabwidth){
					tab.p2 = newseglist[current].p1;
				}
				else{
					split = newseglist[current].splitByLength(tab.location+tab.tabwidth-locus);
					tab.p2 = split[0].p2;
					newseglist.splice(i,1,split[0],split[1]);
				}
			}

			var cutpath:CutPath = new CutPath();
			cutpath.seglist = newseglist;
			cutpath.tabs = tabs;

			return cutpath;
		}
	}

}