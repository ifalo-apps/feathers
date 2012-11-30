/*
Copyright (c) 2012 Josh Tynjala

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
*/
package feathers.display
{
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Sprite;
	import starling.utils.MatrixUtil;

	/**
	 * Adds <code>scrollRect</code> to <code>Sprite</code>.
	 */
	public class Sprite extends starling.display.Sprite implements IDisplayObjectWithScrollRect
	{
		private static const HELPER_POINT:Point = new Point();
		private static const HELPER_MATRIX:Matrix = new Matrix();
		private static const HELPER_RECTANGLE:Rectangle = new Rectangle();
		
		/**
		 * Constructor.
		 */
		public function Sprite()
		{
			super();
		}
		
		/**
		 * @private
		 */
		private var _scrollRect:Rectangle;
		
		/**
		 * @inheritDoc
		 */
		public function get scrollRect():Rectangle
		{
			return this._scrollRect;
		}
		
		/**
		 * @private
		 */
		public function set scrollRect(value:Rectangle):void
		{
			this._scrollRect = value;
			if(this._scrollRect)
			{
				if(!this._scaledScrollRectXY)
				{
					this._scaledScrollRectXY = new Point();
				}
				if(!this._scissorRect)
				{
					this._scissorRect = new Rectangle();
				}
			}
			else
			{
				this._scaledScrollRectXY = null;
				this._scissorRect = null;
			}
		}
		
		private var _scaledScrollRectXY:Point;
		private var _scissorRect:Rectangle;
		
		/**
		 * @inheritDoc
		 */
		override public function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if(this._scrollRect)
			{
				if(!resultRect)
				{
					resultRect = new Rectangle();
				}
				if(targetSpace == this)
				{
					resultRect.x = 0;
					resultRect.y = 0;
					resultRect.width = this._scrollRect.width;
					resultRect.height = this._scrollRect.height;
				}
				else
				{
					this.getTransformationMatrix(targetSpace, HELPER_MATRIX);
					MatrixUtil.transformCoords(HELPER_MATRIX, 0, 0, HELPER_POINT);
					resultRect.x = HELPER_POINT.x;
					resultRect.y = HELPER_POINT.y;
					resultRect.width = HELPER_MATRIX.a * this._scrollRect.width + HELPER_MATRIX.c * this._scrollRect.height;
					resultRect.height = HELPER_MATRIX.d * this._scrollRect.height + HELPER_MATRIX.b * this._scrollRect.width;
				}
				return resultRect;
			}
			
			return super.getBounds(targetSpace, resultRect);
		}
		
		/**
		 * @inheritDoc
		 */
		override public function render(support:RenderSupport, alpha:Number):void
		{
			if(this._scrollRect)
			{
				this.getBounds(this.stage, this._scissorRect);
				
				this.getTransformationMatrix(this.stage, HELPER_MATRIX);
				this._scaledScrollRectXY.x = this._scrollRect.x * HELPER_MATRIX.a;
				this._scaledScrollRectXY.y = this._scrollRect.y * HELPER_MATRIX.d;
				
				const oldRect:Rectangle = ScrollRectManager.currentScissorRect;
				if(oldRect)
				{
					this._scissorRect.x += ScrollRectManager.scrollRectOffsetX;
					this._scissorRect.y += ScrollRectManager.scrollRectOffsetY;
					this._scissorRect = this._scissorRect.intersection(oldRect);
				}
				//round to nearest pixels because the GPU will force it to
				//happen, and the check that follows needs it
				this._scissorRect.x = Math.round(this._scissorRect.x);
				this._scissorRect.y = Math.round(this._scissorRect.y);
				this._scissorRect.width = Math.round(this._scissorRect.width);
				this._scissorRect.height = Math.round(this._scissorRect.height);
				if(this._scissorRect.isEmpty() ||
					this._scissorRect.x >= this.stage.stageWidth ||
					this._scissorRect.y >= this.stage.stageHeight ||
					(this._scissorRect.x + this._scissorRect.width) <= 0 ||
					(this._scissorRect.y + this._scissorRect.height) <= 0)
				{
					//not in bounds of stage. don't render.
					return;
				}
				support.finishQuadBatch();
				support.scissorRectangle = this._scissorRect;
				ScrollRectManager.currentScissorRect = this._scissorRect;
				ScrollRectManager.scrollRectOffsetX -= this._scaledScrollRectXY.x;
				ScrollRectManager.scrollRectOffsetY -= this._scaledScrollRectXY.y;
				support.translateMatrix(-this._scrollRect.x, -this._scrollRect.y);
			}
			super.render(support, alpha);
			if(this._scrollRect)
			{
				support.finishQuadBatch();
				support.translateMatrix(this._scrollRect.x, this._scrollRect.y);
				ScrollRectManager.scrollRectOffsetX += this._scaledScrollRectXY.x;
				ScrollRectManager.scrollRectOffsetY += this._scaledScrollRectXY.y;
				ScrollRectManager.currentScissorRect = oldRect;
				support.scissorRectangle = oldRect;
			}
		}
		
		/**
		 * @inheritDoc
		 */
		override public function hitTest(localPoint:Point, forTouch:Boolean = false):DisplayObject
		{
			if(this._scrollRect)
			{
				//make sure we're in the bounds of this sprite first
				if(this.getBounds(this, HELPER_RECTANGLE).containsPoint(localPoint))
				{
					localPoint.x += this._scrollRect.x;
					localPoint.y += this._scrollRect.y;
					var result:DisplayObject = super.hitTest(localPoint, forTouch);
					localPoint.x -= this._scrollRect.x;
					localPoint.y -= this._scrollRect.y;
					return result;
				}
				return null;
			}
			return super.hitTest(localPoint, forTouch);
		}
	}
}