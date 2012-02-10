package utils.debug {
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.CapsStyle;
import flash.display.JointStyle;
import flash.display.LineScaleMode;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.system.System;
import flash.text.StyleSheet;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.utils.getTimer;

/**
 * Improved Stats
 * https://github.com/MindScriptAct/Hi-ReS-Stats(fork of https://github.com/mrdoob/Hi-ReS-Stats)
 * Merged with : https://github.com/rafaelrinaldi/Hi-ReS-Stats AND https://github.com/shamruk/Hi-ReS-Stats
 *
 * Released under MIT license:
 * http://www.opensource.org/licenses/mit-license.php
 *
 * How to use:
 *
 *	addChild( new Stats() );
 *
 **/

public class Stats extends Sprite {
	
	// stats default size.
	private const DEFAULT_WIDTH:int = 70;
	private const DEFAULT_HEIGHT:int = 100;
	
	private const MINIMIZED_WIDTH:int = 62;
	private const MINIMIZED_HEIGHT:int = 13;
	
	private const MONITOR_WIDTH:int = 500;
	// fps button consts
	private const FPS_BUTTON_XPOS:int = 62;
	private const FPS_BUTTON_YPOS:int = 2;
	private const FPS_BUTTON_SIZE:Number = 6;
	private const FPS_BUTTON_GAP:int = 9;
	private const FPS_BUTTON_2_GAP:int = 21;
	// 
	private const SCROLL_SIZE:Number = 10;
	private const MINIMIZE_BUTTON_SIZE:Number = 5;
	
	// bonus width addet to default WIDTH.
	private var bonusWidth:int = 0;
	
	// stats data in XML format.
	private var statData:XML;
	private var statDataMinimized:XML;
	
	// textField for stats information
	private var statsText:TextField;
	private var style:StyleSheet;
	
	// reacent getTimer value.
	private var timer:uint = 0;
	
	// current stat data
	private var fps:int = 0;
	private var lastTimer:int = 0;
	private var tickTimer:int = 0;
	private var mem:Number = 0;
	private var memMax:Number = 0;
	
	// data for monitoring
	private var frameRateTime:int;
	private var codeTime:uint;
	private var frameTime:uint;
	
	//  graph draw object
	
	private var graph_BD:BitmapData;
	private var clearRect:Rectangle;
	
	// monitoring draw object
	private var monitorView_BD:BitmapData;
	private var monitorView:Bitmap;
	private var codeRect:Rectangle;
	private var renderRect:Rectangle;
	private var clearMonitorRect:Rectangle;
	private var frameRateRect:Rectangle;
	private var monitoringHistoryRect:Rectangle;
	private var monitoringHistoryNewPoint:Point;
	private var monitorSeparatorRect:Rectangle;
	
	// current graph draw value.
	private var fpsGraph:int = 0;
	private var memGraph:int = 0;
	private var memMaxGraph:int = 0;
	
	// object for collor values. (it performs tini bit faster then constants.)
	private var colors:StatColors = new StatColors();
	
	// flag for counter to be in minimized state. (stats are still tracked, but not shown.)
	private var isMinimized:Boolean;
	
	// flag for stats beeing dragable or not.
	private var isDraggable:Boolean = false;
	
	// flag to show application execution and render monitoring.
	private var isMonitoring:Boolean = false;
	
	//
	private var keepGraph:Boolean = false;
	
	/**
	 * <b>Stats</b> FPS, MS and MEM, all in one.
	 * @param isDraggable enables draging functionality.
	 */
	
	public function Stats(width:int = 70, x:int = 0, y:int = 0, isMinimized:Boolean = false, isDraggable:Boolean = true, isMonitoring:Boolean = false):void {
		this.isMinimized = isMinimized;
		
		// calculate increased width.
		bonusWidth = width - DEFAULT_WIDTH;
		if (bonusWidth < 0) {
			bonusWidth = 0;
		}
		
		// initial positioning
		this.x = x;
		this.y = y;
		
		//
		this.isDraggable = isDraggable;
		this.isMonitoring = isMonitoring;
		
		//
		memMax = 0;
		
		// stat data stored in XML formated text.
		statData =       <xmlData>
				<fps>FPS:</fps>
				<ms>MS:</ms>
				<mem>MEM:</mem>
				<memMax>MAX:</memMax>
			</xmlData>;
		
		statDataMinimized =       <xmlData>
				<fps>FPS:</fps>
			</xmlData>;			
		
		// style for stats.
		style = new StyleSheet();
		style.setStyle('xmlData', {fontSize: '9px', fontFamily: '_sans', leading: '-2px'});
		style.setStyle('fps', {color: hex2css(colors.fps)});
		style.setStyle('ms', {color: hex2css(colors.ms)});
		style.setStyle('mem', {color: hex2css(colors.mem)});
		style.setStyle('memMax', {color: hex2css(colors.memMax)});
		
		// text fild to show all stats.
		// TODO : test if it's not more simple just to have 4 text fields without xml and css...
		statsText = new TextField();
		statsText.autoSize = TextFieldAutoSize.LEFT;
		statsText.styleSheet = style;
		statsText.condenseWhite = true;
		statsText.selectable = false;
		statsText.mouseEnabled = false;
		//
		graph_BD = new BitmapData(DEFAULT_WIDTH + bonusWidth, DEFAULT_HEIGHT - 50, false, colors.bg);
		
		//
		addEventListener(Event.ADDED_TO_STAGE, init, false, 0, true);
		addEventListener(Event.REMOVED_FROM_STAGE, destroy, false, 0, true);
	
	}
	
	private function init(event:Event):void {
		
		// add text
		addChild(statsText);
		
		// init objects for later reuse.
		clearRect = new Rectangle(DEFAULT_WIDTH + bonusWidth - 1, 0, 1, DEFAULT_HEIGHT - 50);
		codeRect = new Rectangle(0, 0, -1, 10);
		renderRect = new Rectangle(-1, 0, -1, 10);
		clearMonitorRect = new Rectangle(-1, 0, MONITOR_WIDTH, 10);
		frameRateRect = new Rectangle(frameRateTime, 0, 1, 10);
		monitoringHistoryRect = new Rectangle(0, 9, MONITOR_WIDTH, DEFAULT_HEIGHT);
		monitoringHistoryNewPoint = new Point(0, 10);
		monitorSeparatorRect = new Rectangle(0, 8, MONITOR_WIDTH, 1)
		
		// add events.
		addEventListener(MouseEvent.CLICK, handleClick);
		addEventListener(Event.ENTER_FRAME, handleFrameTick);
		addEventListener(MouseEvent.MOUSE_WHEEL, handleMouseWheel);
		
		// init draging feature.
		if (isDraggable) {
			stage.addEventListener(MouseEvent.MOUSE_UP, handleMouseUp);
			stage.addEventListener(Event.MOUSE_LEAVE, mouseLeaveHandler);
			addEventListener(MouseEvent.MOUSE_DOWN, handleMouseDown);
		}
		
		// draw bg and graph
		initDrawArea();
	
	}
	
	private function initDrawArea():void {
		
		handleBg();
		
		handleGraph();
		
		handleMonitoring();
		
		handleMinimizing();
	}
	
	private function handleBg():void {
		graphics.clear();
		// draw bg.
		graphics.beginFill(colors.bg);
		if (isMinimized) {
			graphics.drawRect(0, 0, MINIMIZED_WIDTH, MINIMIZED_HEIGHT);
		} else {
			graphics.drawRect(0, 0, DEFAULT_WIDTH + bonusWidth, DEFAULT_HEIGHT);
		}
		graphics.endFill();
		
		if (!isMinimized) {
			// draw fps UP/DOWN buttons
			graphics.lineStyle(1, colors.fps, 1, true, LineScaleMode.NORMAL, CapsStyle.SQUARE, JointStyle.MITER);
			// plus sign button
			graphics.drawRect(FPS_BUTTON_XPOS, FPS_BUTTON_YPOS, FPS_BUTTON_SIZE, FPS_BUTTON_SIZE);
			graphics.moveTo(FPS_BUTTON_XPOS + FPS_BUTTON_SIZE / 2, FPS_BUTTON_YPOS);
			graphics.lineTo(FPS_BUTTON_XPOS + FPS_BUTTON_SIZE / 2, FPS_BUTTON_YPOS + FPS_BUTTON_SIZE);
			graphics.moveTo(FPS_BUTTON_XPOS, FPS_BUTTON_YPOS + FPS_BUTTON_SIZE / 2);
			graphics.lineTo(FPS_BUTTON_XPOS + FPS_BUTTON_SIZE, FPS_BUTTON_YPOS + FPS_BUTTON_SIZE / 2);
			// minus sign button
			graphics.drawRect(FPS_BUTTON_XPOS, FPS_BUTTON_YPOS + FPS_BUTTON_GAP, FPS_BUTTON_SIZE, FPS_BUTTON_SIZE);
			graphics.moveTo(FPS_BUTTON_XPOS, FPS_BUTTON_YPOS + FPS_BUTTON_SIZE / 2 + FPS_BUTTON_GAP);
			graphics.lineTo(FPS_BUTTON_XPOS + FPS_BUTTON_SIZE, FPS_BUTTON_YPOS + FPS_BUTTON_SIZE / 2 + FPS_BUTTON_GAP);
			// monitoring on/off button.
			graphics.lineStyle(1, colors.monitorSeparator, 1, true, LineScaleMode.NORMAL, CapsStyle.SQUARE, JointStyle.MITER);
			graphics.drawRect(FPS_BUTTON_XPOS, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP, FPS_BUTTON_SIZE, FPS_BUTTON_SIZE);
			graphics.lineStyle(1, colors.ms, 1, true, LineScaleMode.NORMAL, CapsStyle.SQUARE, JointStyle.MITER);
			graphics.moveTo(FPS_BUTTON_XPOS + 1, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 1);
			graphics.lineTo(FPS_BUTTON_XPOS + 1, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + FPS_BUTTON_SIZE - 1);
			graphics.moveTo(FPS_BUTTON_XPOS + 2, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 1);
			graphics.lineTo(FPS_BUTTON_XPOS + 2, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + FPS_BUTTON_SIZE - 1);
			graphics.lineStyle(1, colors.fps, 1, true, LineScaleMode.NORMAL, CapsStyle.SQUARE, JointStyle.MITER);
			graphics.moveTo(FPS_BUTTON_XPOS + 2, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 1);
			graphics.lineTo(FPS_BUTTON_XPOS + 3, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 1);
			graphics.moveTo(FPS_BUTTON_XPOS + 3, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 2);
			graphics.lineTo(FPS_BUTTON_XPOS + 4, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 2);
			graphics.moveTo(FPS_BUTTON_XPOS + 3, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 2);
			graphics.lineTo(FPS_BUTTON_XPOS + 3, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 3);
			graphics.moveTo(FPS_BUTTON_XPOS + 2, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 4);
			graphics.lineTo(FPS_BUTTON_XPOS + 4, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 4);
			graphics.moveTo(FPS_BUTTON_XPOS + 2, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 5);
			graphics.lineTo(FPS_BUTTON_XPOS + 3, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP + 5);
		}
		//
		graphics.lineStyle();
	}
	
	private function handleGraph():void {
		// draw graph
		if (!isMinimized) {
			if (keepGraph) {
				var oldGraph_BD:BitmapData = graph_BD;
			}
			graph_BD = new BitmapData(DEFAULT_WIDTH + bonusWidth, DEFAULT_HEIGHT - 50, false, colors.bg);
			
			graphics.beginBitmapFill(graph_BD, new Matrix(1, 0, 0, 1, 0, 50));
			graphics.drawRect(0, 50, DEFAULT_WIDTH + bonusWidth, DEFAULT_HEIGHT - 50);
			// if oldGraph is set - drow its content into new graph.
			if (keepGraph) {
				graph_BD.copyPixels(oldGraph_BD, oldGraph_BD.rect, new Point(graph_BD.width - oldGraph_BD.width, 0));
				oldGraph_BD.dispose();
				keepGraph = false;
			}
		}
	}
	
	private function handleMonitoring():void {
		
		// draw button outline.
		if (!isMinimized) {
			if (isMonitoring) {
				frameRateTime = Math.round(1000 / this.stage.frameRate);
				graphics.lineStyle(1, 0xFFFFFF, 1, true, LineScaleMode.NORMAL, CapsStyle.SQUARE, JointStyle.MITER);
				graphics.drawRect(FPS_BUTTON_XPOS, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP, FPS_BUTTON_SIZE, FPS_BUTTON_SIZE);
				graphics.drawRect(FPS_BUTTON_XPOS - 1, FPS_BUTTON_YPOS - 1 + FPS_BUTTON_2_GAP, FPS_BUTTON_SIZE + 2, FPS_BUTTON_SIZE + 2);
			} else {
				graphics.lineStyle(1, colors.monitorSeparator, 1, true, LineScaleMode.NORMAL, CapsStyle.SQUARE, JointStyle.MITER);
				graphics.drawRect(FPS_BUTTON_XPOS, FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP, FPS_BUTTON_SIZE, FPS_BUTTON_SIZE);
				graphics.lineStyle(1, 0x0, 1, true, LineScaleMode.NORMAL, CapsStyle.SQUARE, JointStyle.MITER);
				graphics.drawRect(FPS_BUTTON_XPOS - 1, FPS_BUTTON_YPOS - 1 + FPS_BUTTON_2_GAP, FPS_BUTTON_SIZE + 2, FPS_BUTTON_SIZE + 2);
			}
		}
		graphics.lineStyle();
		
		// handle  monitorView
		if (isMonitoring) {
			if (!monitorView) {
				monitorView_BD = new BitmapData(MONITOR_WIDTH, DEFAULT_HEIGHT, false, colors.bg);
				monitorView = new Bitmap(monitorView_BD);
				this.addChild(monitorView);
			}
			monitorView.visible = true;
			monitorView.x = DEFAULT_WIDTH + bonusWidth + 10;
		} else {
			//
			if (monitorView_BD) {
				monitorView_BD.fillRect(monitorView_BD.rect, colors.bg);
			}
			if (monitorView) {
				monitorView.visible = false;
			}
		}
		
		// hide monitoring if minimized.
		if (isMinimized) {
			if (monitorView) {
				monitorView.visible = false;
			}
		}
		
		// handle ivents
		if (isMonitoring) {
			if (!this.stage.hasEventListener(Event.RENDER)) {
				this.stage.addEventListener(Event.RENDER, handleFrameRender);
			}
		} else {
			if (this.stage.hasEventListener(Event.RENDER)) {
				this.stage.removeEventListener(Event.RENDER, handleFrameRender);
			}
		}
	}
	
	private function handleMinimizing():void {
		// draw button.
		if (isMinimized) {
			graphics.beginFill(0xFF0000)
			graphics.moveTo(-1, 4);
			graphics.lineTo(4, 4);
			graphics.lineTo(4, -1);
			graphics.lineTo(-1, 4);
			graphics.endFill();
			// resize text field down. (so it will not increase boundary area for mous clicks..)
			statsText.height = MINIMIZED_HEIGHT;
		} else {
			graphics.beginFill(0xFF0000)
			graphics.moveTo(-1, 4);
			graphics.lineTo(-1, -1);
			graphics.lineTo(4, -1);
			graphics.lineTo(-1, 4);
			graphics.endFill();
		}
		
		//graphics.moveTo(3, 1);
		//graphics.lineTo(3, 3);
		//graphics.lineTo(1, 3);			
		
		graphics.lineStyle();
	
	}
	
	//----------------------------------
	//     
	//----------------------------------
	
	private function destroy(event:Event):void {
		// clear bg
		graphics.clear();
		
		// remove all childs.
		while (numChildren > 0) {
			removeChildAt(0);
		}
		
		// dispose graph bitmap.
		graph_BD.dispose();
		
		// remove listeners.
		removeEventListener(MouseEvent.CLICK, handleClick);
		removeEventListener(Event.ENTER_FRAME, handleFrameTick);
		
		if (isDraggable) {
			stage.removeEventListener(MouseEvent.MOUSE_UP, handleMouseUp);
			stage.removeEventListener(Event.MOUSE_LEAVE, mouseLeaveHandler);
			removeEventListener(MouseEvent.MOUSE_DOWN, handleMouseDown);
		}
	}
	
	// every frame calculate frame stats.
	private function handleFrameTick(event:Event):void {
		
		frameTime = getTimer() - timer;
		timer = getTimer();
		
		// calculate time change from last tick in ms.
		var tickTime:uint = timer - tickTimer;
		
		// check if more then 1 second passed.
		if (tickTime >= 1000) {
			
			//
			tickTimer = timer;
			
			// calculate ammount of missed seconds. (this can happen then player hangs more then 2 seccond on a job.)
			var missedTicks:uint = (tickTime - 1000) / 1000;
			
			// get current memory.
			mem = Number((System.totalMemory * 0.000000954).toFixed(3));
			
			// update max memory.
			if (memMax < mem) {
				memMax = mem;
			}
			
			// calculate graph point positios.
			fpsGraph = Math.min(graph_BD.height, (fps / stage.frameRate) * graph_BD.height);
			memGraph = Math.min(graph_BD.height, Math.sqrt(Math.sqrt(mem * 5000))) - 2;
			memMaxGraph = Math.min(graph_BD.height, Math.sqrt(Math.sqrt(memMax * 5000))) - 2;
			
			// move graph by 1 pixels for every second passed.
			graph_BD.scroll(-1 - missedTicks, 0);
			
			// clear rectangle area for new graph data.
			if (missedTicks) {
				graph_BD.fillRect(new Rectangle(graph_BD.width - 1 - missedTicks, 0, 1 + missedTicks, DEFAULT_HEIGHT - 50), colors.bg);
			} else {
				graph_BD.fillRect(clearRect, colors.bg);
			}
			
			// draw missed seconds. (if player failed to respond for more then 1 second that means it was hanging, and FPS was < 1 for that time.)
			while (missedTicks) {
				graph_BD.setPixel(graph_BD.width - 1 - missedTicks, graph_BD.height - 1, colors.fps);
				missedTicks--;
			}
			
			// draw current graph data. 
			graph_BD.setPixel(graph_BD.width - 1, graph_BD.height - ((timer - lastTimer) >> 1), colors.ms);
			graph_BD.setPixel(graph_BD.width - 1, graph_BD.height - memGraph, colors.mem);
			graph_BD.setPixel(graph_BD.width - 1, graph_BD.height - memMaxGraph, colors.memMax);
			graph_BD.setPixel(graph_BD.width - 1, graph_BD.height - fpsGraph, colors.fps);
			
			// update data for new frame stats.
			if (isMinimized) {
				statDataMinimized.fps = "FPS: " + fps + " / " + stage.frameRate;
			} else {
				statData.fps = "FPS: " + fps + " / " + stage.frameRate;
				statData.mem = "MEM: " + mem;
				statData.memMax = "MAX: " + memMax;
			}
			
			// frame count for 1 second handled - reset it.
			fps = 0;
		}
		
		// handle monitoring
		if (isMonitoring) {
			this.stage.invalidate();
			
			// drawCodeTime
			codeRect.width = codeTime;
			monitorView_BD.fillRect(codeRect, colors.ms);
			// draw frameTime
			renderRect.x = codeTime + 1;
			renderRect.width = frameTime - codeTime;
			monitorView_BD.fillRect(renderRect, colors.fps);
			// clean rest of the line
			clearMonitorRect.x = frameTime + 1;
			monitorView_BD.fillRect(clearMonitorRect, colors.bg);
			// frame time delimeter
			monitorView_BD.fillRect(frameRateRect, colors.fpsSeparator);
			//
			// move monitoring history one line down
			monitorView_BD.copyPixels(monitorView_BD, monitoringHistoryRect, monitoringHistoryNewPoint);
			// separator for main graph and log.
			monitorView_BD.fillRect(monitorSeparatorRect, colors.monitorSeparator);
			
		}
		
		// time in ms for one frame tick.
		statData.ms = "MS: " + frameTime;
		
		// update data text.
		if (isMinimized) {
			statsText.htmlText = statDataMinimized;
		} else {
			statsText.htmlText = statData;
		}
		
		// increse frame tick count by 1.
		fps++;
		
		//
		lastTimer = timer;
	}
	
	// handle click over stat object.
	private function handleClick(event:MouseEvent):void {
		// check if click is in button area.
		if (!isMinimized) {
			if (this.mouseX > FPS_BUTTON_XPOS) {
				if (this.mouseX < FPS_BUTTON_XPOS + FPS_BUTTON_SIZE) {
					// add fps button
					if (this.mouseY > FPS_BUTTON_YPOS) {
						if (this.mouseY < FPS_BUTTON_YPOS + FPS_BUTTON_SIZE) {
							stage.frameRate = Math.round(stage.frameRate + 1);
							statData.fps = "FPS: " + fps + " / " + stage.frameRate;
							statsText.htmlText = statData;
							
						}
					}
					// remove fps button
					if (this.mouseY > FPS_BUTTON_YPOS + FPS_BUTTON_GAP) {
						if (this.mouseY < FPS_BUTTON_YPOS + FPS_BUTTON_SIZE + FPS_BUTTON_GAP) {
							stage.frameRate = Math.round(stage.frameRate - 1);
							statData.fps = "FPS: " + fps + " / " + stage.frameRate;
							statsText.htmlText = statData;
						}
					}
					// toggle monitoring button
					if (this.mouseY > FPS_BUTTON_YPOS + FPS_BUTTON_2_GAP) {
						if (this.mouseY < FPS_BUTTON_YPOS + FPS_BUTTON_SIZE + FPS_BUTTON_2_GAP) {
							isMonitoring = !isMonitoring;
							handleMonitoring();
						}
					}
					
					// recalculate fpsRate. (needed if it is changed.)
					if (isMonitoring) {
						frameRateTime = Math.round(1000 / this.stage.frameRate);
						frameRateRect.x = frameRateTime;
					}
				}
			}
		}
		
		// minimize button
		if (this.mouseX < MINIMIZE_BUTTON_SIZE) {
			if (this.mouseY < MINIMIZE_BUTTON_SIZE) {
				isMinimized = !isMinimized;
				initDrawArea();
				fitToStage();
			}
		}
	}
	
	// handle mouseWheel
	private function handleMouseWheel(event:MouseEvent):void {
		if (event.delta > 0) {
			bonusWidth += SCROLL_SIZE;
		} else {
			bonusWidth -= SCROLL_SIZE;
			if (bonusWidth < 0) {
				bonusWidth = 0;
			}
		}
		// clear bg
		graphics.clear();
		// flag graph to be preserved.
		keepGraph = true;
		// redraw bg
		initDrawArea();
	}
	
	// 
	private function handleFrameRender(event:Event):void {
		codeTime = getTimer() - timer;
	}
	
	//----------------------------------
	//     Dragging functions
	//----------------------------------
	
	// start dragging
	private function handleMouseDown(event:MouseEvent):void {
		this.stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
	}
	
	// stop dragging
	private function handleMouseUp(event:MouseEvent):void {
		this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
	}
	
	// handle dragging
	private function mouseMoveHandler(event:MouseEvent):void {
		// calculete new possitions.
		if (isMinimized) {
			this.x = this.stage.mouseX - MINIMIZED_WIDTH * 0.5;
			this.y = this.stage.mouseY - MINIMIZED_HEIGHT * 0.5;
		} else {
			this.x = this.stage.mouseX - DEFAULT_WIDTH * 0.5;
			this.y = this.stage.mouseY - DEFAULT_HEIGHT * 0.5;
		}
		fitToStage();
	}
	
	private function fitToStage():void {
		if (isMinimized) {
			
			// handle x bounds
			if (this.x > this.stage.stageWidth - MINIMIZED_WIDTH) {
				this.x = this.stage.stageWidth - MINIMIZED_WIDTH;
			}
			// handle y bounds.
			if (this.y > this.stage.stageHeight - MINIMIZED_HEIGHT) {
				this.y = this.stage.stageHeight - MINIMIZED_HEIGHT;
			}
		} else {
			
			// handle x bounds
			if (this.x > this.stage.stageWidth - this.width) {
				this.x = this.stage.stageWidth - this.width;
			}
			// handle y bounds.
			if (this.y > this.stage.stageHeight - this.height) {
				this.y = this.stage.stageHeight - this.height;
			}
		}
		// handle x bounds
		if (this.x < 0) {
			this.x = 0;
		}
		// handle y bounds.
		if (this.y < 0) {
			this.y = 0;
		}
	}
	
	// handle mous leaving the screen.
	private function mouseLeaveHandler(event:Event):void {
		this.stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
	}
	
	//----------------------------------
	//     Utils
	//----------------------------------
	
	// converts color number to hex value.
	private function hex2css(color:int):String {
		return "#" + color.toString(16);
	}

}
}

// helper class to store graph corols.
class StatColors {
	public var bg:uint = 0x000033;
	public var fps:uint = 0xFFFF00;
	public var ms:uint = 0x00FF00;
	public var mem:uint = 0x00FFFF;
	public var memMax:uint = 0xFF0070;
	
	public var fpsSeparator:uint = 0xFF0000;
	public var monitorSeparator:int = 0xD8D8D8;

}