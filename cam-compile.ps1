Add-Type -A System.Drawing
# made sure everything here compiled with out you needing to install visual studio or cmake or any other garbage
# which is something that is kinda a lost art nowadays :(
$cam = @"
using System.Drawing;
using System.Threading;
using AForge.Video;

public class Cam
{
	public static AutoResetEvent waithandle = new AutoResetEvent(false);
	public static bool captured = false;

	public static void VideoSource_NewFrame(object sender, NewFrameEventArgs eventArgs)
	{
		if (captured)
			return;

		captured = true;

		Bitmap bitmap = (Bitmap)eventArgs.Frame.Clone();
		bitmap.Save("cap.jpg", System.Drawing.Imaging.ImageFormat.Jpeg);

		waithandle.Set();
	}
}
namespace AForge.Video
{
	using System;
	using System.Drawing;
	using System.Threading;
	using System.Drawing.Imaging;
	public class AsyncVideoSource : IVideoSource
	{
		private readonly IVideoSource nestedVideoSource = null;
		private Bitmap lastVideoFrame = null;

		private Thread imageProcessingThread = null;
		private AutoResetEvent isNewFrameAvailable = null;
		private AutoResetEvent isProcessingThreadAvailable = null;
		private bool skipFramesIfBusy = false;
		private int framesProcessed;
		public event NewFrameEventHandler NewFrame;
		public event VideoSourceErrorEventHandler VideoSourceError
		{
			add { nestedVideoSource.VideoSourceError += value; }
			remove { nestedVideoSource.VideoSourceError -= value; }
		}
		public event PlayingFinishedEventHandler PlayingFinished
		{
			add { nestedVideoSource.PlayingFinished += value; }
			remove { nestedVideoSource.PlayingFinished -= value; }
		}
		public IVideoSource NestedVideoSource
		{
			get { return nestedVideoSource; }
		}
		public bool SkipFramesIfBusy
		{
			get { return skipFramesIfBusy; }
			set { skipFramesIfBusy = value; }
		}
		public string Source
		{
			get { return nestedVideoSource.Source; }
		}
		public int FramesReceived
		{
			get { return nestedVideoSource.FramesReceived; }
		}
		public long BytesReceived
		{
			get { return nestedVideoSource.BytesReceived; }
		}
		public int FramesProcessed
		{
			get
			{
				int frames = framesProcessed;
				framesProcessed = 0;
				return frames;
			}
		}
		public bool IsRunning
		{
			get
			{
				bool isRunning = nestedVideoSource.IsRunning;

				if ( !isRunning )
				{
					Free( );
				}

				return isRunning;
			}
		}
		public AsyncVideoSource( IVideoSource nestedVideoSource )
		{
			this.nestedVideoSource = nestedVideoSource;
		}
		public AsyncVideoSource( IVideoSource nestedVideoSource, bool skipFramesIfBusy )
		{
			this.nestedVideoSource = nestedVideoSource;
			this.skipFramesIfBusy = skipFramesIfBusy;
		}
		public void Start( )
		{
			if ( !IsRunning )
			{
				framesProcessed = 0;
				isNewFrameAvailable = new AutoResetEvent( false );
				isProcessingThreadAvailable = new AutoResetEvent( true );
				imageProcessingThread = new Thread( new ThreadStart( imageProcessingThread_Worker ) );
				imageProcessingThread.Start( );
				nestedVideoSource.NewFrame += new NewFrameEventHandler( nestedVideoSource_NewFrame );
				nestedVideoSource.Start( );
			}
		}
		public void SignalToStop( )
		{
			nestedVideoSource.SignalToStop( );
			Free( );
		}
		public void WaitForStop( )
		{
			nestedVideoSource.WaitForStop( );
			Free( );
		}
		public void Stop( )
		{
			nestedVideoSource.Stop( );
			Free( );
		}

		private void Free( )
		{
			if ( imageProcessingThread != null )
			{
				nestedVideoSource.NewFrame -= new NewFrameEventHandler( nestedVideoSource_NewFrame );
				isProcessingThreadAvailable.WaitOne( );
				lastVideoFrame = null;
				isNewFrameAvailable.Set( );
				imageProcessingThread.Join( );
				imageProcessingThread = null;
				isNewFrameAvailable.Close( );
				isNewFrameAvailable = null;

				isProcessingThreadAvailable.Close( );
				isProcessingThreadAvailable = null;
			}
		}
		private void nestedVideoSource_NewFrame( object sender, NewFrameEventArgs eventArgs )
		{
			if ( NewFrame == null )
				return;

			if ( skipFramesIfBusy )
			{
				if ( !isProcessingThreadAvailable.WaitOne( 0, false ) )
				{
					return;
				}
			}
			else
			{
				isProcessingThreadAvailable.WaitOne( );
			}
			lastVideoFrame = CloneImage( eventArgs.Frame );
			isNewFrameAvailable.Set( );
		}

		private void imageProcessingThread_Worker( )
		{
			while ( true )
			{
				isNewFrameAvailable.WaitOne( );
				if ( lastVideoFrame == null )
				{
					break;
				}

				if ( NewFrame != null )
				{
					NewFrame( this, new NewFrameEventArgs( lastVideoFrame ) );
				}

				lastVideoFrame.Dispose( );
				lastVideoFrame = null;
				framesProcessed++;
				isProcessingThreadAvailable.Set( );
			}
		}

		private static Bitmap CloneImage( Bitmap source )
		{
			BitmapData sourceData = source.LockBits(
				new Rectangle( 0, 0, source.Width, source.Height ),
				ImageLockMode.ReadOnly, source.PixelFormat );
			Bitmap destination = CloneImage( sourceData );
			source.UnlockBits( sourceData );
			if (
				( source.PixelFormat == PixelFormat.Format1bppIndexed ) ||
				( source.PixelFormat == PixelFormat.Format4bppIndexed ) ||
				( source.PixelFormat == PixelFormat.Format8bppIndexed ) ||
				( source.PixelFormat == PixelFormat.Indexed ) )
			{
				ColorPalette srcPalette = source.Palette;
				ColorPalette dstPalette = destination.Palette;

				int n = srcPalette.Entries.Length;
				for ( int i = 0; i < n; i++ )
				{
					dstPalette.Entries[i] = srcPalette.Entries[i];
				}

				destination.Palette = dstPalette;
			}

			return destination;
		}

		private static Bitmap CloneImage( BitmapData sourceData )
		{
			int width = sourceData.Width;
			int height = sourceData.Height;
			Bitmap destination = new Bitmap( width, height, sourceData.PixelFormat );
			BitmapData destinationData = destination.LockBits(
				new Rectangle( 0, 0, width, height ),
				ImageLockMode.ReadWrite, destination.PixelFormat );
			destination.UnlockBits( destinationData );

			return destination;
		}
	}
	internal static class ByteArrayUtils
	{
		public static bool Compare( byte[] array, byte[] needle, int startIndex )
		{
			int needleLen = needle.Length;
			for ( int i = 0, p = startIndex; i < needleLen; i++, p++ )
			{
				if ( array[p] != needle[i] )
				{
					return false;
				}
			}
			return true;
		}
		public static int Find( byte[] array, byte[] needle, int startIndex, int sourceLength )
		{
			int needleLen = needle.Length;
			int index;

			while ( sourceLength >= needleLen )
			{
				index = Array.IndexOf( array, needle[0], startIndex, sourceLength - needleLen + 1 );
				if ( index == -1 )
					return -1;

				int i, p;
				for ( i = 0, p = index; i < needleLen; i++, p++ )
				{
					if ( array[p] != needle[i] )
					{
						break;
					}
				}

				if ( i == needleLen )
				{
					return index;
				}
				sourceLength -= ( index - startIndex + 1 );
				startIndex = index + 1;
			}
			return -1;
		}
	}
	public class VideoException : Exception
	{
		public VideoException( string message ) :
			base( message ) { }
	}
	public interface IVideoSource
	{
		event NewFrameEventHandler NewFrame;
		event VideoSourceErrorEventHandler VideoSourceError;
		event PlayingFinishedEventHandler PlayingFinished;
		string Source { get; }
		int FramesReceived { get; }
		long BytesReceived { get; }
		bool IsRunning { get; }
		void Start( );
		void SignalToStop( );
		void WaitForStop( );
		void Stop( );
	}
	public delegate void NewFrameEventHandler( object sender, NewFrameEventArgs eventArgs );
	public delegate void VideoSourceErrorEventHandler( object sender, VideoSourceErrorEventArgs eventArgs );
	public delegate void PlayingFinishedEventHandler( object sender, ReasonToFinishPlaying reason );
	public enum ReasonToFinishPlaying
	{
		EndOfStreamReached,
		StoppedByUser,
		DeviceLost,
		VideoSourceError
	}
	public class NewFrameEventArgs : EventArgs
	{
		private System.Drawing.Bitmap frame;
		public NewFrameEventArgs( System.Drawing.Bitmap frame )
		{
			this.frame = frame;
		}
		public System.Drawing.Bitmap Frame
		{
			get { return frame; }
		}
	}
	public class VideoSourceErrorEventArgs : EventArgs
	{
		private string description;
		public VideoSourceErrorEventArgs( string description )
		{
			this.description = description;
		}
		public string Description
		{
			get { return description; }
		}
	}
}
namespace AForge.Video.DirectShow
{
	using System;
	using System.IO;
	using System.Drawing;
	using System.Threading;
	using System.Collections;
	using System.Drawing.Imaging;
	using System.Collections.Generic;
	using System.Runtime.InteropServices;
	using System.Runtime.InteropServices.ComTypes;

	using AForge.Video;
	using AForge.Video.DirectShow.Internals;
	public class VideoCaptureDevice : IVideoSource
	{
		private string deviceMoniker;
		private int framesReceived;
		private long bytesReceived;
		private VideoCapabilities videoResolution = null;
		private VideoCapabilities snapshotResolution = null;
		private bool provideSnapshots = false;
		private bool preferJpegEncoding = true;
		private bool jpegEncodingEnabled = false;

		private Thread thread = null;
		private ManualResetEvent stopEvent = null;

		private VideoCapabilities[] videoCapabilities;
		private VideoCapabilities[] snapshotCapabilities;

		private bool needToSetVideoInput = false;
		private bool needToSimulateTrigger = false;
		private bool needToDisplayPropertyPage = false;
		private bool needToDisplayCrossBarPropertyPage = false;
		private IntPtr parentWindowForPropertyPage = IntPtr.Zero;
		private object sourceObject = null;
		private DateTime startTime = new DateTime( );
		private object sync = new object( );
		private bool? isCrossbarAvailable = null;

		private VideoInput[] crossbarVideoInputs = null;
		private VideoInput crossbarVideoInput = VideoInput.Default;
		private static Dictionary<string, VideoCapabilities[]> cacheVideoCapabilities = new Dictionary<string,VideoCapabilities[]>( );
		private static Dictionary<string, VideoCapabilities[]> cacheSnapshotCapabilities = new Dictionary<string,VideoCapabilities[]>( );
		private static Dictionary<string, VideoInput[]> cacheCrossbarVideoInputs = new Dictionary<string,VideoInput[]>( );
		public VideoInput CrossbarVideoInput
		{
			get { return crossbarVideoInput; }
			set
			{
				needToSetVideoInput = true;
				crossbarVideoInput = value;
			}
		}
		public VideoInput[] AvailableCrossbarVideoInputs
		{
			get
			{
				if ( crossbarVideoInputs == null )
				{
					lock ( cacheCrossbarVideoInputs )
					{
						if ( ( !string.IsNullOrEmpty( deviceMoniker ) ) && ( cacheCrossbarVideoInputs.ContainsKey( deviceMoniker ) ) )
						{
							crossbarVideoInputs = cacheCrossbarVideoInputs[deviceMoniker];
						}
					}

					if ( crossbarVideoInputs == null )
					{
						if ( !IsRunning )
						{
							WorkerThread( false );
						}
						else
						{
							for ( int i = 0; ( i < 500 ) && ( crossbarVideoInputs == null ); i++ )
							{
								Thread.Sleep( 10 );
							}
						}
					}
				}
				return ( crossbarVideoInputs != null ) ? crossbarVideoInputs : new VideoInput[0];
			}
		}
		public bool ProvideSnapshots
		{
			get { return provideSnapshots; }
			set { provideSnapshots = value; }
		}
		public bool PreferJpegEncoding
		{
			get { return preferJpegEncoding; }
			set { preferJpegEncoding = value;  }
		}
		public bool JpegEncodingEnabled
		{
			get { return JpegEncodingEnabled; }
		}
		public event NewFrameEventHandler NewFrame;
		public event NewFrameEventHandler SnapshotFrame;
		public event VideoSourceErrorEventHandler VideoSourceError;
		public event PlayingFinishedEventHandler PlayingFinished;
		public virtual string Source
		{
			get { return deviceMoniker; }
			set
			{
				deviceMoniker = value;

				videoCapabilities = null;
				snapshotCapabilities = null;
				crossbarVideoInputs = null;
				isCrossbarAvailable = null;
			}
		}
		public int FramesReceived
		{
			get
			{
				int frames = framesReceived;
				framesReceived = 0;
				return frames;
			}
		}
		public long BytesReceived
		{
			get
			{
				long bytes = bytesReceived;
				bytesReceived = 0;
				return bytes;
			}
		}
		public bool IsRunning
		{
			get
			{
				if ( thread != null )
				{
					if ( thread.Join( 0 ) == false )
						return true;
					Free( );
				}
				return false;
			}
		}
		[Obsolete]
		public Size DesiredFrameSize
		{
			get { return Size.Empty; }
			set { }
		}
		[Obsolete]
		public Size DesiredSnapshotSize
		{
			get { return Size.Empty; }
			set { }
		}
		[Obsolete]
		public int DesiredFrameRate
		{
			get { return 0; }
			set { }
		}
		public VideoCapabilities VideoResolution
		{
			get { return videoResolution; }
			set { videoResolution = value; }
		}
		public VideoCapabilities SnapshotResolution
		{
			get { return snapshotResolution; }
			set { snapshotResolution = value; }
		}
		public VideoCapabilities[] VideoCapabilities
		{
			get
			{
				if ( videoCapabilities == null )
				{
					lock ( cacheVideoCapabilities )
					{
						if ( ( !string.IsNullOrEmpty( deviceMoniker ) ) && ( cacheVideoCapabilities.ContainsKey( deviceMoniker ) ) )
						{
							videoCapabilities = cacheVideoCapabilities[deviceMoniker];
						}
					}

					if ( videoCapabilities == null )
					{
						if ( !IsRunning )
						{
							WorkerThread( false );
						}
						else
						{
							for ( int i = 0; ( i < 500 ) && ( videoCapabilities == null ); i++ )
							{
								Thread.Sleep( 10 );
							}
						}
					}
				}
				return ( videoCapabilities != null ) ? videoCapabilities : new VideoCapabilities[0];
			}
		}
		public VideoCapabilities[] SnapshotCapabilities
		{
			get
			{
				if ( snapshotCapabilities == null )
				{
					lock ( cacheSnapshotCapabilities )
					{
						if ( ( !string.IsNullOrEmpty( deviceMoniker ) ) && ( cacheSnapshotCapabilities.ContainsKey( deviceMoniker ) ) )
						{
							snapshotCapabilities = cacheSnapshotCapabilities[deviceMoniker];
						}
					}

					if ( snapshotCapabilities == null )
					{
						if ( !IsRunning )
						{
							WorkerThread( false );
						}
						else
						{
							for ( int i = 0; ( i < 500 ) && ( snapshotCapabilities == null ); i++ )
							{
								Thread.Sleep( 10 );
							}
						}
					}
				}
				return ( snapshotCapabilities != null ) ? snapshotCapabilities : new VideoCapabilities[0];
			}
		}
		public object SourceObject
		{
			get { return sourceObject; }
		}
		public VideoCaptureDevice( ) { }
		public VideoCaptureDevice( string deviceMoniker )
		{
			this.deviceMoniker = deviceMoniker;
		}
		public void Start( )
		{
			if ( !IsRunning )
			{
				if ( string.IsNullOrEmpty( deviceMoniker ) )
					throw new ArgumentException( "Video source is not specified." );

				framesReceived = 0;
				bytesReceived = 0;
				isCrossbarAvailable = null;
				needToSetVideoInput = true;
				stopEvent = new ManualResetEvent( false );

				lock ( sync )
				{
					thread = new Thread( new ThreadStart( WorkerThread ) );
					thread.Name = deviceMoniker;
					thread.Start( );
				}
			}
		}
		public void SignalToStop( )
		{
			if ( thread != null )
			{
				stopEvent.Set( );
			}
		}
		public void WaitForStop( )
		{
			if ( thread != null )
			{
				thread.Join( );

				Free( );
			}
		}
		public void Stop( )
		{
			if ( this.IsRunning )
			{
				thread.Abort( );
				WaitForStop( );
			}
		}
		private void Free( )
		{
			thread = null;
			stopEvent.Close( );
			stopEvent = null;
		}
		public void DisplayPropertyPage( IntPtr parentWindow )
		{
			if ( ( deviceMoniker == null ) || ( deviceMoniker == string.Empty ) )
				throw new ArgumentException( "Video source is not specified." );

			lock ( sync )
			{
				if ( IsRunning )
				{
					parentWindowForPropertyPage = parentWindow;
					needToDisplayPropertyPage = true;
					return;
				}

				object tempSourceObject = null;
				try
				{
					tempSourceObject = FilterInfo.CreateFilter( deviceMoniker );
				}
				catch
				{
					throw new ApplicationException( "Failed creating device object for moniker." );
				}

				if ( !( tempSourceObject is ISpecifyPropertyPages ) )
				{
					throw new NotSupportedException( "The video source does not support configuration property page." );
				}

				DisplayPropertyPage( parentWindow, tempSourceObject );

				Marshal.ReleaseComObject( tempSourceObject );
			}
		}
		public void DisplayCrossbarPropertyPage( IntPtr parentWindow )
		{
			lock ( sync )
			{
				for ( int i = 0; ( i < 500 ) && ( !isCrossbarAvailable.HasValue ) && ( IsRunning ); i++ )
				{
					Thread.Sleep( 10 );
				}

				if ( ( !IsRunning ) || ( !isCrossbarAvailable.HasValue ) )
				{
					throw new ApplicationException( "The video source must be running in order to display crossbar property page." );
				}

				if ( !isCrossbarAvailable.Value )
				{
					throw new NotSupportedException( "Crossbar configuration is not supported by currently running video source." );
				}
				parentWindowForPropertyPage = parentWindow;
				needToDisplayCrossBarPropertyPage = true;
			}
		}
		public bool CheckIfCrossbarAvailable( )
		{
			lock ( sync )
			{
				if ( !isCrossbarAvailable.HasValue )
				{
					if ( !IsRunning )
					{
						WorkerThread( false );
					}
					else
					{
						for ( int i = 0; ( i < 500 ) && ( !isCrossbarAvailable.HasValue ); i++ )
						{
							Thread.Sleep( 10 );
						}
					}
				}

				return ( !isCrossbarAvailable.HasValue ) ? false : isCrossbarAvailable.Value;
			}
		}
		public void SimulateTrigger( )
		{
			needToSimulateTrigger = true;
		}
		public bool SetCameraProperty( CameraControlProperty property, int value, CameraControlFlags controlFlags )
		{
			bool ret = true;
			if ( ( deviceMoniker == null ) || ( string.IsNullOrEmpty( deviceMoniker ) ) )
			{
				throw new ArgumentException( "Video source is not specified." );
			}

			lock ( sync )
			{
				object tempSourceObject = null;
				try
				{
					tempSourceObject = FilterInfo.CreateFilter( deviceMoniker );
				}
				catch
				{
					throw new ApplicationException( "Failed creating device object for moniker." );
				}

				if ( !( tempSourceObject is IAMCameraControl ) )
				{
					throw new NotSupportedException( "The video source does not support camera control." );
				}

				IAMCameraControl pCamControl = (IAMCameraControl) tempSourceObject;
				int hr = pCamControl.Set( property, value, controlFlags );

				ret = ( hr >= 0 );

				Marshal.ReleaseComObject( tempSourceObject );
			}

			return ret;
		}
		public bool GetCameraProperty( CameraControlProperty property, out int value, out CameraControlFlags controlFlags )
		{
			bool ret = true;
			if ( ( deviceMoniker == null ) || ( string.IsNullOrEmpty( deviceMoniker ) ) )
			{
				throw new ArgumentException( "Video source is not specified." );
			}

			lock ( sync )
			{
				object tempSourceObject = null;
				try
				{
					tempSourceObject = FilterInfo.CreateFilter( deviceMoniker );
				}
				catch
				{
					throw new ApplicationException( "Failed creating device object for moniker." );
				}

				if ( !( tempSourceObject is IAMCameraControl ) )
				{
					throw new NotSupportedException( "The video source does not support camera control." );
				}

				IAMCameraControl pCamControl = (IAMCameraControl) tempSourceObject;
				int hr = pCamControl.Get( property, out value, out controlFlags );

				ret = ( hr >= 0 );

				Marshal.ReleaseComObject( tempSourceObject );
			}

			return ret;
		}
		public bool GetCameraPropertyRange( CameraControlProperty property, out int minValue, out int maxValue, out int stepSize, out int defaultValue, out CameraControlFlags controlFlags )
		{
			bool ret = true;
			if ( ( deviceMoniker == null ) || ( string.IsNullOrEmpty( deviceMoniker ) ) )
			{
				throw new ArgumentException( "Video source is not specified." );
			}

			lock ( sync )
			{
				object tempSourceObject = null;
				try
				{
					tempSourceObject = FilterInfo.CreateFilter( deviceMoniker );
				}
				catch
				{
					throw new ApplicationException( "Failed creating device object for moniker." );
				}

				if ( !( tempSourceObject is IAMCameraControl ) )
				{
					throw new NotSupportedException( "The video source does not support camera control." );
				}

				IAMCameraControl pCamControl = (IAMCameraControl) tempSourceObject;
				int hr = pCamControl.GetRange( property, out minValue, out maxValue, out stepSize, out defaultValue, out controlFlags );

				ret = ( hr >= 0 );

				Marshal.ReleaseComObject( tempSourceObject );
			}

			return ret;
		}
		private void WorkerThread( )
		{
			WorkerThread( true );
		}

		private void WorkerThread( bool runGraph )
		{
			ReasonToFinishPlaying reasonToStop = ReasonToFinishPlaying.StoppedByUser;
			bool isSapshotSupported = false;
			Grabber videoGrabber = new Grabber( this, false );
			Grabber snapshotGrabber = new Grabber( this, true );
			object captureGraphObject = null;
			object graphObject = null;
			object videoGrabberObject = null;
			object snapshotGrabberObject = null;
			object crossbarObject = null;
			ICaptureGraphBuilder2 captureGraph = null;
			IFilterGraph2   graph = null;
			IBaseFilter	 sourceBase = null;
			IBaseFilter	 videoGrabberBase = null;
			IBaseFilter	 snapshotGrabberBase = null;
			ISampleGrabber  videoSampleGrabber = null;
			ISampleGrabber  snapshotSampleGrabber = null;
			IMediaControl   mediaControl = null;
			IAMVideoControl videoControl = null;
			IMediaEventEx   mediaEvent = null;
			IPin			pinStillImage = null;
			IAMCrossbar	 crossbar = null;

			try
			{
				Type type = Type.GetTypeFromCLSID( Clsid.CaptureGraphBuilder2 );
				if ( type == null )
					throw new ApplicationException( "Failed creating capture graph builder" );
				captureGraphObject = Activator.CreateInstance( type );
				captureGraph = (ICaptureGraphBuilder2) captureGraphObject;
				type = Type.GetTypeFromCLSID( Clsid.FilterGraph );
				if ( type == null )
					throw new ApplicationException( "Failed creating filter graph" );
				graphObject = Activator.CreateInstance( type );
				graph = (IFilterGraph2) graphObject;
				captureGraph.SetFiltergraph( (IGraphBuilder) graph );
				sourceObject = FilterInfo.CreateFilter( deviceMoniker );
				if ( sourceObject == null )
					throw new ApplicationException( "Failed creating device object for moniker" );
				sourceBase = (IBaseFilter) sourceObject;
				try
				{
					videoControl = (IAMVideoControl) sourceObject;
				}
				catch
				{
				}
				type = Type.GetTypeFromCLSID( Clsid.SampleGrabber );
				if ( type == null )
					throw new ApplicationException( "Failed creating sample grabber" );
				videoGrabberObject = Activator.CreateInstance( type );
				videoSampleGrabber = (ISampleGrabber) videoGrabberObject;
				videoGrabberBase = (IBaseFilter) videoGrabberObject;
				snapshotGrabberObject = Activator.CreateInstance( type );
				snapshotSampleGrabber = (ISampleGrabber) snapshotGrabberObject;
				snapshotGrabberBase = (IBaseFilter) snapshotGrabberObject;
				graph.AddFilter( sourceBase, "source" );
				graph.AddFilter( videoGrabberBase, "grabber_video" );
				graph.AddFilter( snapshotGrabberBase, "grabber_snapshot" );
				if ( preferJpegEncoding )
				{
					jpegEncodingEnabled = IsJpegEncodingAvailable( sourceBase );
				}
				AMMediaType videoMediaType = new AMMediaType( );
				videoMediaType.MajorType = MediaType.Video;
				videoMediaType.SubType   = ( jpegEncodingEnabled ) ? MediaSubType.MJpeg : MediaSubType.RGB24;

				AMMediaType snapshotMediaType = new AMMediaType( );
				snapshotMediaType.MajorType = MediaType.Video;
				snapshotMediaType.SubType   = MediaSubType.RGB24;

				videoSampleGrabber.SetMediaType( videoMediaType );
				snapshotSampleGrabber.SetMediaType( snapshotMediaType );
				captureGraph.FindInterface( FindDirection.UpstreamOnly, Guid.Empty, sourceBase, typeof( IAMCrossbar ).GUID, out crossbarObject );
				if ( crossbarObject != null )
				{
					crossbar = (IAMCrossbar) crossbarObject;
				}
				isCrossbarAvailable = ( crossbar != null );
				crossbarVideoInputs = ColletCrossbarVideoInputs( crossbar );

				if ( videoControl != null )
				{
					captureGraph.FindPin( sourceObject, PinDirection.Output,
						PinCategory.StillImage, MediaType.Video, false, 0, out pinStillImage );
					if ( pinStillImage != null )
					{
						VideoControlFlags caps;
						videoControl.GetCaps( pinStillImage, out caps );
						isSapshotSupported = ( ( ( caps & VideoControlFlags.ExternalTriggerEnable ) != 0 ) ||
											   ( ( caps & VideoControlFlags.Trigger ) != 0 ) );
					}
				}
				videoSampleGrabber.SetBufferSamples( false );
				videoSampleGrabber.SetOneShot( false );
				videoSampleGrabber.SetCallback( videoGrabber, 1 );
				snapshotSampleGrabber.SetBufferSamples( true );
				snapshotSampleGrabber.SetOneShot( false );
				snapshotSampleGrabber.SetCallback( snapshotGrabber, 1 );
				GetPinCapabilitiesAndConfigureSizeAndRate( captureGraph, sourceBase,
					PinCategory.Capture, videoResolution, ref videoCapabilities );
				if ( isSapshotSupported )
				{
					GetPinCapabilitiesAndConfigureSizeAndRate( captureGraph, sourceBase,
						PinCategory.StillImage, snapshotResolution, ref snapshotCapabilities );
				}
				else
				{
					snapshotCapabilities = new VideoCapabilities[0];
				}
				lock ( cacheVideoCapabilities )
				{
					if ( ( videoCapabilities != null ) && ( !cacheVideoCapabilities.ContainsKey( deviceMoniker ) ) )
					{
						cacheVideoCapabilities.Add( deviceMoniker, videoCapabilities );
					}
				}
				lock ( cacheSnapshotCapabilities )
				{
					if ( ( snapshotCapabilities != null ) && ( !cacheSnapshotCapabilities.ContainsKey( deviceMoniker ) ) )
					{
						cacheSnapshotCapabilities.Add( deviceMoniker, snapshotCapabilities );
					}
				}

				if ( runGraph )
				{
					AMMediaType mediaType = new AMMediaType( ); ;
					captureGraph.RenderStream( PinCategory.Capture, MediaType.Video, sourceBase, null, videoGrabberBase );

					if ( videoSampleGrabber.GetConnectedMediaType( mediaType ) == 0 )
					{
						VideoInfoHeader vih = (VideoInfoHeader) Marshal.PtrToStructure( mediaType.FormatPtr, typeof( VideoInfoHeader ) );

						videoGrabber.Width = vih.BmiHeader.Width;
						videoGrabber.Height = vih.BmiHeader.Height;
						
						mediaType.Dispose( );
					}

					if ( ( isSapshotSupported ) && ( provideSnapshots ) )
					{
						captureGraph.RenderStream( PinCategory.StillImage, MediaType.Video, sourceBase, null, snapshotGrabberBase );

						if ( snapshotSampleGrabber.GetConnectedMediaType( mediaType ) == 0 )
						{
							VideoInfoHeader vih = (VideoInfoHeader) Marshal.PtrToStructure( mediaType.FormatPtr, typeof( VideoInfoHeader ) );

							snapshotGrabber.Width  = vih.BmiHeader.Width;
							snapshotGrabber.Height = vih.BmiHeader.Height;

							mediaType.Dispose( );
						}
					}
					mediaControl = (IMediaControl) graphObject;
					mediaEvent = (IMediaEventEx) graphObject;
					IntPtr p1, p2;
					DsEvCode code;
					mediaControl.Run( );

					if ( ( isSapshotSupported ) && ( provideSnapshots ) )
					{
						startTime = DateTime.Now;
						videoControl.SetMode( pinStillImage, VideoControlFlags.ExternalTriggerEnable );
					}

					do
					{
						if ( mediaEvent != null )
						{
							if ( mediaEvent.GetEvent( out code, out p1, out p2, 0 ) >= 0 )
							{
								mediaEvent.FreeEventParams( code, p1, p2 );

								if ( code == DsEvCode.DeviceLost )
								{
									reasonToStop = ReasonToFinishPlaying.DeviceLost;
									break;
								}
							}
						}

						if ( needToSetVideoInput )
						{
							needToSetVideoInput = false;
							if ( isCrossbarAvailable.Value )
							{
								SetCurrentCrossbarInput( crossbar, crossbarVideoInput );
								crossbarVideoInput = GetCurrentCrossbarInput( crossbar );
							}
						}

						if ( needToSimulateTrigger )
						{
							needToSimulateTrigger = false;

							if ( ( isSapshotSupported ) && ( provideSnapshots ) )
							{
								videoControl.SetMode( pinStillImage, VideoControlFlags.Trigger );
							}
						}

						if ( needToDisplayPropertyPage )
						{
							needToDisplayPropertyPage = false;
							DisplayPropertyPage( parentWindowForPropertyPage, sourceObject );

							if ( crossbar != null )
							{
								crossbarVideoInput = GetCurrentCrossbarInput( crossbar );
							}
						}

						if ( needToDisplayCrossBarPropertyPage )
						{
							needToDisplayCrossBarPropertyPage = false;

							if ( crossbar != null )
							{
								DisplayPropertyPage( parentWindowForPropertyPage, crossbar );
								crossbarVideoInput = GetCurrentCrossbarInput( crossbar );
							}
						}
					}
					while ( !stopEvent.WaitOne( 100, false ) );

					mediaControl.Stop( );
				}
			}
			catch ( Exception exception )
			{
				if ( VideoSourceError != null )
				{
					VideoSourceError( this, new VideoSourceErrorEventArgs( exception.Message ) );
				}
			}
			finally
			{
				captureGraph	= null;
				graph		   = null;
				sourceBase	  = null;
				mediaControl	= null;
				videoControl	= null;
				mediaEvent	  = null;
				pinStillImage   = null;
				crossbar		= null;

				videoGrabberBase	  = null;
				snapshotGrabberBase   = null;
				videoSampleGrabber	= null;
				snapshotSampleGrabber = null;

				if ( graphObject != null )
				{
					Marshal.ReleaseComObject( graphObject );
					graphObject = null;
				}
				if ( sourceObject != null )
				{
					Marshal.ReleaseComObject( sourceObject );
					sourceObject = null;
				}
				if ( videoGrabberObject != null )
				{
					Marshal.ReleaseComObject( videoGrabberObject );
					videoGrabberObject = null;
				}
				if ( snapshotGrabberObject != null )
				{
					Marshal.ReleaseComObject( snapshotGrabberObject );
					snapshotGrabberObject = null;
				}
				if ( captureGraphObject != null )
				{
					Marshal.ReleaseComObject( captureGraphObject );
					captureGraphObject = null;
				}
				if ( crossbarObject != null )
				{
					Marshal.ReleaseComObject( crossbarObject );
					crossbarObject = null;
				}
			}

			if ( PlayingFinished != null )
			{
				PlayingFinished( this, reasonToStop );
			}

			jpegEncodingEnabled = false;
		}
		private bool IsJpegEncodingAvailable( IBaseFilter baseFilter )
		{
			bool	  ret	 = false;
			IEnumPins pinEnum = null;
			IPin[]	pins	= new IPin[1];
			int	   pinsFetched;

			if ( ( baseFilter.EnumPins( out pinEnum ) == 0 ) && ( pinEnum  != null ) )
			{
				try
				{
					while ( ( pinEnum.Next( 1, pins, out pinsFetched ) == 0 ) && ( !ret ) )
					{
						PinDirection pinDir;

						if ( ( pins[0].QueryDirection( out pinDir ) == 0 ) && ( pinDir == PinDirection.Output ) )
						{
							IEnumMediaTypes mediaEnum  = null;
							AMMediaType[]   mediaTypes = new AMMediaType[1];
							int			 typesFetched;

							if ( pins[0].EnumMediaTypes( out mediaEnum ) == 0 )
							{
								try
								{
									while ( ( mediaEnum.Next( 1, mediaTypes, out typesFetched ) == 0 ) && ( !ret ) )
									{
										if ( ( mediaTypes[0].MajorType == MediaType.Video ) && ( mediaTypes[0].SubType == MediaSubType.MJpeg ))
										{
											ret = true;
										}

										mediaTypes[0].Dispose( );
									}
								}
								finally
								{
									Marshal.ReleaseComObject( mediaEnum );
								}
							}
						}
					}
				}
				finally
				{
					Marshal.ReleaseComObject( pinEnum );
				}
			}

			return ret;
		}
		private void SetResolution( IAMStreamConfig streamConfig, VideoCapabilities resolution )
		{
			if ( resolution == null )
			{
				return;
			}
			int capabilitiesCount = 0, capabilitySize = 0;
			AMMediaType newMediaType = null;
			VideoStreamConfigCaps caps = new VideoStreamConfigCaps( );

			streamConfig.GetNumberOfCapabilities( out capabilitiesCount, out capabilitySize );

			for ( int i = 0; i < capabilitiesCount; i++ )
			{
				try
				{
					VideoCapabilities vc = new VideoCapabilities( streamConfig, i );

					if ( resolution == vc )
					{
						if ( streamConfig.GetStreamCaps( i, out newMediaType, caps ) == 0 )
						{
							break;
						}
					}
				}
				catch
				{
				}
			}
			if ( newMediaType != null )
			{
				streamConfig.SetFormat( newMediaType );
				newMediaType.Dispose( );
			}
		}
		private void GetPinCapabilitiesAndConfigureSizeAndRate( ICaptureGraphBuilder2 graphBuilder, IBaseFilter baseFilter,
			Guid pinCategory, VideoCapabilities resolutionToSet, ref VideoCapabilities[] capabilities )
		{
			object streamConfigObject;
			graphBuilder.FindInterface( pinCategory, MediaType.Video, baseFilter, typeof( IAMStreamConfig ).GUID, out streamConfigObject );

			if ( streamConfigObject != null )
			{
				IAMStreamConfig streamConfig = null;

				try
				{
					streamConfig = (IAMStreamConfig) streamConfigObject;
				}
				catch ( InvalidCastException )
				{
				}

				if ( streamConfig != null )
				{
					if ( capabilities == null )
					{
						try
						{
							capabilities = AForge.Video.DirectShow.VideoCapabilities.FromStreamConfig( streamConfig );
						}
						catch
						{
						}
					}
					if ( resolutionToSet != null )
					{
						SetResolution( streamConfig, resolutionToSet );
					}
				}

				Marshal.ReleaseComObject( streamConfigObject );
			}
			if ( capabilities == null )
			{
				capabilities = new VideoCapabilities[0];
			}
		}
		private void DisplayPropertyPage( IntPtr parentWindow, object sourceObject )
		{
			try
			{
				ISpecifyPropertyPages pPropPages = (ISpecifyPropertyPages) sourceObject;
				CAUUID caGUID;
				pPropPages.GetPages( out caGUID );
				FilterInfo filterInfo = new FilterInfo( deviceMoniker );
				Win32.OleCreatePropertyFrame( parentWindow, 0, 0, filterInfo.Name, 1, ref sourceObject, caGUID.cElems, caGUID.pElems, 0, 0, IntPtr.Zero );
				Marshal.FreeCoTaskMem( caGUID.pElems );
			}
			catch
			{
			}
		}
		private VideoInput[] ColletCrossbarVideoInputs( IAMCrossbar crossbar )
		{
			lock ( cacheCrossbarVideoInputs )
			{
				if ( cacheCrossbarVideoInputs.ContainsKey( deviceMoniker ) )
				{
					return cacheCrossbarVideoInputs[deviceMoniker];
				}

				List<VideoInput> videoInputsList = new List<VideoInput>( );

				if ( crossbar != null )
				{
					int inPinsCount, outPinsCount;
					if ( crossbar.get_PinCounts( out outPinsCount, out inPinsCount ) == 0 )
					{
						for ( int i = 0; i < inPinsCount; i++ )
						{
							int pinIndexRelated;
							PhysicalConnectorType type;

							if ( crossbar.get_CrossbarPinInfo( true, i, out pinIndexRelated, out type ) != 0 )
								continue;

							if ( type < PhysicalConnectorType.AudioTuner )
							{
								videoInputsList.Add( new VideoInput( i, type ) );
							}
						}
					}
				}

				VideoInput[] videoInputs = new VideoInput[videoInputsList.Count];
				videoInputsList.CopyTo( videoInputs );

				cacheCrossbarVideoInputs.Add( deviceMoniker, videoInputs );

				return videoInputs;
			}
		}
		private VideoInput GetCurrentCrossbarInput( IAMCrossbar crossbar )
		{
			VideoInput videoInput = VideoInput.Default;

			int inPinsCount, outPinsCount;
			if ( crossbar.get_PinCounts( out outPinsCount, out inPinsCount ) == 0 )
			{
				int videoOutputPinIndex = -1;
				int pinIndexRelated;
				PhysicalConnectorType type;
				for ( int i = 0; i < outPinsCount; i++ )
				{
					if ( crossbar.get_CrossbarPinInfo( false, i, out pinIndexRelated, out type ) != 0 )
						continue;

					if ( type == PhysicalConnectorType.VideoDecoder )
					{
						videoOutputPinIndex = i;
						break;
					}
				}

				if ( videoOutputPinIndex != -1 )
				{
					int videoInputPinIndex;
					if ( crossbar.get_IsRoutedTo( videoOutputPinIndex, out videoInputPinIndex ) == 0 )
					{
						PhysicalConnectorType inputType;

						crossbar.get_CrossbarPinInfo( true, videoInputPinIndex, out pinIndexRelated, out inputType );

						videoInput = new VideoInput( videoInputPinIndex, inputType );
					}
				}
			}

			return videoInput;
		}
		private void SetCurrentCrossbarInput( IAMCrossbar crossbar, VideoInput videoInput )
		{
			if ( videoInput.Type != PhysicalConnectorType.Default )
			{
				int inPinsCount, outPinsCount;
				if ( crossbar.get_PinCounts( out outPinsCount, out inPinsCount ) == 0 )
				{
					int videoOutputPinIndex = -1;
					int videoInputPinIndex = -1;
					int pinIndexRelated;
					PhysicalConnectorType type;
					for ( int i = 0; i < outPinsCount; i++ )
					{
						if ( crossbar.get_CrossbarPinInfo( false, i, out pinIndexRelated, out type ) != 0 )
							continue;

						if ( type == PhysicalConnectorType.VideoDecoder )
						{
							videoOutputPinIndex = i;
							break;
						}
					}
					for ( int i = 0; i < inPinsCount; i++ )
					{
						if ( crossbar.get_CrossbarPinInfo( true, i, out pinIndexRelated, out type ) != 0 )
							continue;

						if ( ( type == videoInput.Type ) && ( i == videoInput.Index ) )
						{
							videoInputPinIndex = i;
							break;
						}
					}
					if ( ( videoInputPinIndex != -1 ) && ( videoOutputPinIndex != -1 ) &&
						 ( crossbar.CanRoute( videoOutputPinIndex, videoInputPinIndex ) == 0 ) )
					{
						crossbar.Route( videoOutputPinIndex, videoInputPinIndex );
					}
				}
			}
		}
		private void OnNewFrame( Bitmap image )
		{
			framesReceived++;
			bytesReceived += image.Width * image.Height * ( Bitmap.GetPixelFormatSize( image.PixelFormat ) >> 3 );

			if ( ( !stopEvent.WaitOne( 0, false ) ) && ( NewFrame != null ) )
				NewFrame( this, new NewFrameEventArgs( image ) );
		}
		private void OnSnapshotFrame( Bitmap image )
		{
			TimeSpan timeSinceStarted = DateTime.Now - startTime;
			if ( timeSinceStarted.TotalSeconds >= 4 )
			{
				if ( ( !stopEvent.WaitOne( 0, false ) ) && ( SnapshotFrame != null ) )
					SnapshotFrame( this, new NewFrameEventArgs( image ) );
			}
		}
		private class Grabber : ISampleGrabberCB
		{
			private VideoCaptureDevice parent;
			private bool snapshotMode;
			private int width, height;
			public int Width
			{
				get { return width; }
				set { width = value; }
			}
			public int Height
			{
				get { return height; }
				set { height = value; }
			}
			public Grabber( VideoCaptureDevice parent, bool snapshotMode )
			{
				this.parent = parent;
				this.snapshotMode = snapshotMode;
			}
			public int SampleCB( double sampleTime, IntPtr sample )
			{
				return 0;
			}
			public int BufferCB( double sampleTime, IntPtr buffer, int bufferLen )
			{
				if ( parent.NewFrame != null )
				{
					System.Drawing.Bitmap image = null;

					if ( !parent.jpegEncodingEnabled )
					{
						image = new Bitmap( width, height, PixelFormat.Format24bppRgb );
						BitmapData imageData = image.LockBits(
							new Rectangle( 0, 0, width, height ),
							ImageLockMode.ReadWrite,
							PixelFormat.Format24bppRgb );
						int srcStride = imageData.Stride;
						int dstStride = imageData.Stride;

						unsafe
						{
							byte* dst = (byte*) imageData.Scan0.ToPointer( ) + dstStride * ( height - 1 );
							byte* src = (byte*) buffer.ToPointer( );

							for ( int y = 0; y < height; y++ )
							{
								Win32.memcpy( dst, src, srcStride );
								dst -= dstStride;
								src += srcStride;
							}
						}
						image.UnlockBits( imageData );
					}
					else
					{
						unsafe
						{
							image = (Bitmap)Bitmap.FromStream( new UnmanagedMemoryStream( (byte*)buffer.ToPointer( ), bufferLen ) );
						}
					}

					if ( image != null )
					{
						if (snapshotMode)
						{
							parent.OnSnapshotFrame( image );
						}
						else
						{
							parent.OnNewFrame( image );
						}
						image.Dispose( );
					}
				}

				return 0;
			}
		}
	}
	public class VideoCapabilities
	{
		public readonly Size FrameSize;
		[Obsolete( "No longer supported. Use AverageFrameRate instead." )]
		public int FrameRate
		{
			get { return AverageFrameRate; }
		}
		public readonly int AverageFrameRate;
		public readonly int MaximumFrameRate;
		public readonly int BitCount;

		internal VideoCapabilities( ) { }
		static internal VideoCapabilities[] FromStreamConfig( IAMStreamConfig videoStreamConfig )
		{
			if ( videoStreamConfig == null )
				throw new ArgumentNullException( "videoStreamConfig" );
			int count, size;
			int hr = videoStreamConfig.GetNumberOfCapabilities( out count, out size );

			if ( hr != 0 )
				Marshal.ThrowExceptionForHR( hr );

			if ( count <= 0 )
				throw new NotSupportedException( "This video device does not report capabilities." );

			if ( size > Marshal.SizeOf( typeof( VideoStreamConfigCaps ) ) )
				throw new NotSupportedException( "Unable to retrieve video device capabilities. This video device requires a larger VideoStreamConfigCaps structure." );
			Dictionary<uint, VideoCapabilities> videocapsList = new Dictionary<uint, VideoCapabilities>( );

			for ( int i = 0; i < count; i++ )
			{
				try
				{
					VideoCapabilities vc = new VideoCapabilities( videoStreamConfig, i );

					uint key = ( ( (uint) vc.FrameSize.Height ) << 32 ) |
							   ( ( (uint) vc.FrameSize.Width ) << 16 );

					if ( !videocapsList.ContainsKey( key ) )
					{
						videocapsList.Add( key, vc );
					}
					else
					{
						if ( vc.BitCount > videocapsList[key].BitCount )
						{
							videocapsList[key] = vc;
						}
					}
				}
				catch
				{
				}
			}

			VideoCapabilities[] videocaps = new VideoCapabilities[videocapsList.Count];
			videocapsList.Values.CopyTo( videocaps, 0 );

			return videocaps;
		}
		internal VideoCapabilities( IAMStreamConfig videoStreamConfig, int index )
		{
			AMMediaType mediaType = null;
			VideoStreamConfigCaps caps = new VideoStreamConfigCaps( );

			try
			{
				int hr = videoStreamConfig.GetStreamCaps( index, out mediaType, caps );

				if ( hr != 0 )
					Marshal.ThrowExceptionForHR( hr );

				if ( mediaType.FormatType == FormatType.VideoInfo )
				{
					VideoInfoHeader videoInfo = (VideoInfoHeader) Marshal.PtrToStructure( mediaType.FormatPtr, typeof( VideoInfoHeader ) );

					FrameSize = new Size( videoInfo.BmiHeader.Width, videoInfo.BmiHeader.Height );
					BitCount = videoInfo.BmiHeader.BitCount;
					AverageFrameRate = (int) ( 10000000 / videoInfo.AverageTimePerFrame );
					MaximumFrameRate = (int) ( 10000000 / caps.MinFrameInterval );
				}
				else if ( mediaType.FormatType == FormatType.VideoInfo2 )
				{
					VideoInfoHeader2 videoInfo = (VideoInfoHeader2) Marshal.PtrToStructure( mediaType.FormatPtr, typeof( VideoInfoHeader2 ) );

					FrameSize = new Size( videoInfo.BmiHeader.Width, videoInfo.BmiHeader.Height );
					BitCount = videoInfo.BmiHeader.BitCount;
					AverageFrameRate = (int) ( 10000000 / videoInfo.AverageTimePerFrame );
					MaximumFrameRate = (int) ( 10000000 / caps.MinFrameInterval );
				}
				else
				{
					throw new ApplicationException( "Unsupported format found." );
				}
				if ( BitCount <= 12 )
				{
					throw new ApplicationException( "Unsupported format found." );
				}
			}
			finally
			{
				if ( mediaType != null )
					mediaType.Dispose( );
			}
		}
		public override bool Equals( object obj )
		{
			return Equals( obj as VideoCapabilities );
		}
		public bool Equals( VideoCapabilities vc2 )
		{
			if ( (object) vc2 == null )
			{
				return false;
			}

			return ( ( FrameSize == vc2.FrameSize ) && ( BitCount == vc2.BitCount ) );
		}
		public override int GetHashCode( )
		{
			return FrameSize.GetHashCode( ) ^ BitCount;
		}
		public static bool operator ==( VideoCapabilities a, VideoCapabilities b )
		{
			if ( object.ReferenceEquals( a, b ) )
			{
				return true;
			}
			if ( ( (object) a == null ) || ( (object) b == null ) )
			{
				return false;
			}

			return a.Equals( b );
		}
		public static bool operator !=( VideoCapabilities a, VideoCapabilities b )
		{
			return !( a == b );
		}
	}
	public class VideoInput
	{
		public readonly int Index;
		public readonly PhysicalConnectorType Type;

		internal VideoInput( int index, PhysicalConnectorType type )
		{
			Index = index;
			Type = type;
		}
		public static VideoInput Default
		{
			get { return new VideoInput( -1, PhysicalConnectorType.Default ); }
		}
	}
	public class FilterInfo : IComparable
	{
		public string Name { get; private set; }
		public string MonikerString { get; private set; }
		public FilterInfo( string monikerString )
		{
			MonikerString = monikerString;
			Name = GetName( monikerString );
		}
		internal FilterInfo( IMoniker moniker )
		{
			MonikerString = GetMonikerString( moniker );
			Name = GetName( moniker );
		}
		public int CompareTo( object value )
		{
			FilterInfo f = (FilterInfo) value;

			if ( f == null )
				return 1;

			return ( this.Name.CompareTo( f.Name ) );
		}
		public static object CreateFilter( string filterMoniker )
		{
			object filterObject = null;
			IBindCtx bindCtx = null;
			IMoniker moniker = null;

			int n = 0;
			if ( Win32.CreateBindCtx( 0, out bindCtx ) == 0 )
			{
				if ( Win32.MkParseDisplayName( bindCtx, filterMoniker, ref n, out moniker ) == 0 )
				{
					Guid filterId = typeof( IBaseFilter ).GUID;
					moniker.BindToObject( null, null, ref filterId, out filterObject );

					Marshal.ReleaseComObject( moniker );
				}
				Marshal.ReleaseComObject( bindCtx );
			}
			return filterObject;
		}
		private string GetMonikerString( IMoniker moniker )
		{
			string str;
			moniker.GetDisplayName( null, null, out str );
			return str;
		}
		private string GetName( IMoniker moniker )
		{
			Object bagObj = null;
			IPropertyBag bag = null;

			try
			{
				Guid bagId = typeof( IPropertyBag ).GUID;
				moniker.BindToStorage( null, null, ref bagId, out bagObj );
				bag = (IPropertyBag) bagObj;
				object val = "";
				int hr = bag.Read( "FriendlyName", ref val, IntPtr.Zero );
				if ( hr != 0 )
					Marshal.ThrowExceptionForHR( hr );
				string ret = (string) val;
				if ( ( ret == null ) || ( ret.Length < 1 ) )
					throw new ApplicationException( );

				return ret;
			}
			catch ( Exception )
			{
				return "";
			}
			finally
			{
				bag = null;
				if ( bagObj != null )
				{
					Marshal.ReleaseComObject( bagObj );
					bagObj = null;
				}
			}
		}
		private string GetName( string monikerString )
		{
			IBindCtx bindCtx = null;
			IMoniker moniker = null;
			String name = "";
			int n = 0;
			if ( Win32.CreateBindCtx( 0, out bindCtx ) == 0 )
			{
				if ( Win32.MkParseDisplayName( bindCtx, monikerString, ref n, out moniker ) == 0 )
				{
					name = GetName( moniker );

					Marshal.ReleaseComObject( moniker );
					moniker = null;
				}
				Marshal.ReleaseComObject( bindCtx );
				bindCtx = null;
			}
			return name;
		}
	}
	public class FilterInfoCollection : CollectionBase
	{
		public FilterInfoCollection( Guid category )
		{
			CollectFilters( category );
		}
		public FilterInfo this[int index]
		{
			get
			{
				return ( (FilterInfo) InnerList[index] );
			}
		}
		private void CollectFilters( Guid category )
		{
			object comObj = null;
			ICreateDevEnum enumDev = null;
			IEnumMoniker enumMon = null;
			IMoniker[] devMon = new IMoniker[1];
			int	hr;

			try
			{
				Type srvType = Type.GetTypeFromCLSID( Clsid.SystemDeviceEnum );
				if ( srvType == null )
					throw new ApplicationException( "Failed creating device enumerator" );
				comObj = Activator.CreateInstance( srvType );
				enumDev = (ICreateDevEnum) comObj;
				hr = enumDev.CreateClassEnumerator( ref category, out enumMon, 0 );
				if ( hr != 0 )
					throw new ApplicationException( "No devices of the category" );
				IntPtr n = IntPtr.Zero;
				while ( true )
				{
					hr = enumMon.Next( 1, devMon, n );
					if ( ( hr != 0 ) || ( devMon[0] == null ) )
						break;
					FilterInfo filter = new FilterInfo( devMon[0] );
					InnerList.Add( filter );
					Marshal.ReleaseComObject( devMon[0] );
					devMon[0] = null;
				}
				InnerList.Sort( );
			}
			catch
			{
			}
			finally
			{
				enumDev = null;
				if ( comObj != null )
				{
					Marshal.ReleaseComObject( comObj );
					comObj = null;
				}
				if ( enumMon != null )
				{
					Marshal.ReleaseComObject( enumMon );
					enumMon = null;
				}
				if ( devMon[0] != null )
				{
					Marshal.ReleaseComObject( devMon[0] );
					devMon[0] = null;
				}
			}
		}
	}
}
namespace AForge.Video.DirectShow.Internals
{
	using System;
	using System.Drawing;
	using System.Runtime.InteropServices;
	using System.Runtime.InteropServices.ComTypes;
	abstract internal class DSMarshaler : ICustomMarshaler
	{
		protected string cookie;
		protected object obj;

		public DSMarshaler( string cookie )
		{
			this.cookie = cookie;
		}
		virtual public IntPtr MarshalManagedToNative( object managedObj )
		{
			this.obj = managedObj;
			int	size = GetNativeDataSize( ) + 3;
			IntPtr ptr  = Marshal.AllocCoTaskMem( size );

			for ( int x = 0; x < size / 4; x++ )
			{
				Marshal.WriteInt32( ptr, x * 4, 0 );
			}

			return ptr;
		}
		virtual public object MarshalNativeToManaged( IntPtr ptrNativeData )
		{
			return this.obj;
		}
		virtual public void CleanUpNativeData( IntPtr ptrNativeData )
		{
			if (ptrNativeData != IntPtr.Zero )
			{
				Marshal.FreeCoTaskMem( ptrNativeData );
			}
		}
		virtual public void CleanUpManagedData( object managedObj )
		{
			this.obj = null;
		}
		abstract public int GetNativeDataSize( );
	}
	internal class EMTMarshaler : DSMarshaler
	{
		public EMTMarshaler( string cookie ) : base( cookie )
		{
		}
		override public object MarshalNativeToManaged( IntPtr ptrNativeData )
		{
			AMMediaType[] emt = this.obj as AMMediaType[];

			for ( int x = 0; x < emt.Length; x++ )
			{
				IntPtr ptr = Marshal.ReadIntPtr( ptrNativeData, x * IntPtr.Size );
				if ( ptr != IntPtr.Zero)
				{
					emt[x] = (AMMediaType) Marshal.PtrToStructure( ptr, typeof( AMMediaType ) );
				}
				else
				{
					emt[x] = null;
				}
			}

			return null;
		}
		override public int GetNativeDataSize( )
		{
			int len = ( (Array) this.obj ).Length;
			int size = len * IntPtr.Size;

			return size;
		}
		public static ICustomMarshaler GetInstance( string cookie )
		{
			return new EMTMarshaler( cookie );
		}
	}
	[ComImport,
	Guid( "C6E13370-30AC-11d0-A18C-00A0C9118956" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IAMCameraControl
	{
		[PreserveSig]
		int GetRange(
			[In] CameraControlProperty Property,
			[Out] out int pMin,
			[Out] out int pMax,
			[Out] out int pSteppingDelta,
			[Out] out int pDefault,
			[Out] out CameraControlFlags pCapsFlags
			);
		[PreserveSig]
		int Set(
			[In] CameraControlProperty Property,
			[In] int lValue,
			[In] CameraControlFlags Flags
			);
		[PreserveSig]
		int Get(
			[In] CameraControlProperty Property,
			[Out] out int lValue,
			[Out] out CameraControlFlags Flags
			);
	}
	[ComImport, System.Security.SuppressUnmanagedCodeSecurity,
	Guid( "C6E13380-30AC-11D0-A18C-00A0C9118956" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IAMCrossbar
	{
		[PreserveSig]
		int get_PinCounts( [Out] out int outputPinCount, [Out] out int inputPinCount );
		[PreserveSig]
		int CanRoute( [In] int outputPinIndex, [In] int inputPinIndex );
		[PreserveSig]
		int Route( [In] int outputPinIndex, [In] int inputPinIndex );
		[PreserveSig]
		int get_IsRoutedTo( [In] int outputPinIndex, [Out] out int inputPinIndex );
		[PreserveSig]
		int get_CrossbarPinInfo(
			[In, MarshalAs( UnmanagedType.Bool )] bool isInputPin,
			[In] int pinIndex,
			[Out] out int pinIndexRelated,
			[Out] out PhysicalConnectorType physicalType );
	}
	[ComImport,
	Guid( "C6E13340-30AC-11d0-A18C-00A0C9118956" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IAMStreamConfig
	{
		[PreserveSig]
		int SetFormat( [In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int GetFormat( [Out, MarshalAs( UnmanagedType.LPStruct )] out AMMediaType mediaType );
		[PreserveSig]
		int GetNumberOfCapabilities( out int count, out int size );
		[PreserveSig]
		int GetStreamCaps(
			[In] int index,
			[Out, MarshalAs( UnmanagedType.LPStruct )] out AMMediaType mediaType,
			[In, MarshalAs( UnmanagedType.LPStruct )] VideoStreamConfigCaps streamConfigCaps
			);
	}
	[ComImport,
	Guid( "6A2E0670-28E4-11D0-A18c-00A0C9118956" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IAMVideoControl
	{
		[PreserveSig]
		int GetCaps( [In] IPin pin, [Out, MarshalAs( UnmanagedType.I4 )] out VideoControlFlags flags );
		[PreserveSig]
		int SetMode( [In] IPin pin, [In, MarshalAs( UnmanagedType.I4 )] VideoControlFlags mode );
		[PreserveSig]
		int GetMode( [In] IPin pin, [Out, MarshalAs( UnmanagedType.I4 )] out VideoControlFlags mode );
		[PreserveSig]
		int GetCurrentActualFrameRate( [In] IPin pin, [Out, MarshalAs( UnmanagedType.I8 )] out long actualFrameRate );
		[PreserveSig]
		int GetMaxAvailableFrameRate( [In] IPin pin, [In] int index, 
			[In] System.Drawing.Size dimensions,
			[Out] out long maxAvailableFrameRate );
		[PreserveSig]
		int GetFrameRateList( [In] IPin pin, [In] int index,
			[In] System.Drawing.Size dimensions,
			[Out] out int listSize,
			[Out] out IntPtr frameRate );
	}
	[ComImport,
	Guid( "56A86895-0AD4-11CE-B03A-0020AF0BA770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IBaseFilter
	{
		[PreserveSig]
		int GetClassID( [Out] out Guid ClassID );
		[PreserveSig]
		int Stop( );
		[PreserveSig]
		int Pause( );
		[PreserveSig]
		int Run( long start );
		[PreserveSig]
		int GetState( int milliSecsTimeout, [Out] out int filterState );
		[PreserveSig]
		int SetSyncSource( [In] IntPtr clock );
		[PreserveSig]
		int GetSyncSource( [Out] out IntPtr clock );
		[PreserveSig]
		int EnumPins( [Out] out IEnumPins enumPins );
		[PreserveSig]
		int FindPin( [In, MarshalAs( UnmanagedType.LPWStr )] string id, [Out] out IPin pin );
		[PreserveSig]
		int QueryFilterInfo( [Out] out FilterInfo filterInfo );
		[PreserveSig]
		int JoinFilterGraph( [In] IFilterGraph graph, [In, MarshalAs( UnmanagedType.LPWStr )] string name );
		[PreserveSig]
		int QueryVendorInfo( [Out, MarshalAs( UnmanagedType.LPWStr )] out string vendorInfo );
	}
	[ComImport,
	Guid( "93E5A4E0-2D50-11d2-ABFA-00A0C9C6E38D" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface ICaptureGraphBuilder2
	{
		[PreserveSig]
		int SetFiltergraph( [In] IGraphBuilder graphBuilder );
		[PreserveSig]
		int GetFiltergraph( [Out] out IGraphBuilder graphBuilder );
		[PreserveSig]
		int SetOutputFileName(
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid type,
			[In, MarshalAs( UnmanagedType.LPWStr )] string fileName,
			[Out] out IBaseFilter baseFilter,
			[Out] out IntPtr fileSinkFilter
			);
		[PreserveSig]
		int FindInterface(
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid category,
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid type,
			[In] IBaseFilter baseFilter,
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid interfaceID ,
			[Out, MarshalAs( UnmanagedType.IUnknown )] out object retInterface
			);
		[PreserveSig]
		int RenderStream(
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid category,
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid mediaType,
			[In, MarshalAs( UnmanagedType.IUnknown )] object source,
			[In] IBaseFilter compressor,
			[In] IBaseFilter renderer
			);
		[PreserveSig]
		int ControlStream(
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid category,
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid mediaType,
			[In, MarshalAs( UnmanagedType.Interface )] IBaseFilter filter,
			[In] long start,
			[In] long stop,
			[In] short startCookie,
			[In] short stopCookie
			);
		[PreserveSig]
		int AllocCapFile(
			[In, MarshalAs( UnmanagedType.LPWStr )] string fileName,
			[In] long size
			);
		[PreserveSig]
		int CopyCaptureFile(
			[In, MarshalAs( UnmanagedType.LPWStr )] string oldFileName,
			[In, MarshalAs( UnmanagedType.LPWStr )] string newFileName,
			[In, MarshalAs( UnmanagedType.Bool )] bool allowEscAbort,
			[In] IntPtr callback
			);
		[PreserveSig]
		int FindPin(
			[In, MarshalAs( UnmanagedType.IUnknown )] object source,
			[In] PinDirection pinDirection,
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid category,
			[In, MarshalAs( UnmanagedType.LPStruct )] Guid mediaType,
			[In, MarshalAs( UnmanagedType.Bool )] bool unconnected,
			[In] int index,
			[Out, MarshalAs( UnmanagedType.Interface )] out IPin pin
			);
	}
	[ComImport,
	Guid( "29840822-5B84-11D0-BD3B-00A0C911CE86" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface ICreateDevEnum
	{
		[PreserveSig]
		int CreateClassEnumerator( [In] ref Guid type, [Out] out IEnumMoniker enumMoniker, [In] int flags );
	}
	[ComImport,
	Guid( "56A86893-0AD4-11CE-B03A-0020AF0BA770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IEnumFilters
	{
		[PreserveSig]
		int Next( [In] int cFilters,
			[Out, MarshalAs( UnmanagedType.LPArray, SizeParamIndex = 0 )] IBaseFilter[] filters,
			[Out] out int filtersFetched );
		[PreserveSig]
		int Skip( [In] int cFilters );
		[PreserveSig]
		int Reset( );
		[PreserveSig]
		int Clone( [Out] out IEnumFilters enumFilters );
	}
	[ComImport,
	Guid( "89C31040-846B-11CE-97D3-00AA0055595A" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IEnumMediaTypes
	{
		[PreserveSig]
		int Next( [In] int cMediaTypes,
			[In, Out, MarshalAs( UnmanagedType.CustomMarshaler, MarshalTypeRef = typeof( EMTMarshaler ), SizeParamIndex = 0 )] AMMediaType[] mediaTypes,
			[Out] out int typesFetched );
		[PreserveSig]
		int Skip( [In] int cMediaTypes );
		[PreserveSig]
		int Reset( );
		[PreserveSig]
		int Clone( [Out] out IEnumPins enumMediaTypes );
	}
	[ComImport,
	Guid( "56A86892-0AD4-11CE-B03A-0020AF0BA770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IEnumPins
	{
		[PreserveSig]
		int Next( [In] int cPins,
			[Out, MarshalAs( UnmanagedType.LPArray, SizeParamIndex = 0 )] IPin[] pins,
			[Out] out int pinsFetched );
		[PreserveSig]
		int Skip( [In] int cPins );
		[PreserveSig]
		int Reset( );
		[PreserveSig]
		int Clone( [Out] out IEnumPins enumPins );
	}
	[ComImport,
	Guid( "56A868A6-0Ad4-11CE-B03A-0020AF0BA770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IFileSourceFilter
	{
		[PreserveSig]
		int Load( [In, MarshalAs( UnmanagedType.LPWStr )] string fileName,
			[In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int GetCurFile([Out, MarshalAs( UnmanagedType.LPWStr )] out string fileName,
			[Out, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
	}
	[ComImport,
	Guid( "56A8689F-0AD4-11CE-B03A-0020AF0BA770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IFilterGraph
	{
		[PreserveSig]
		int AddFilter( [In] IBaseFilter filter, [In, MarshalAs( UnmanagedType.LPWStr )] string name );
		[PreserveSig]
		int RemoveFilter( [In] IBaseFilter filter );
		[PreserveSig]
		int EnumFilters( [Out] out IntPtr enumerator );
		[PreserveSig]
		int FindFilterByName( [In, MarshalAs( UnmanagedType.LPWStr )] string name, [Out] out IBaseFilter filter );
		[PreserveSig]
		int ConnectDirect( [In] IPin pinOut, [In] IPin pinIn, [In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int Reconnect( [In] IPin pin );
		[PreserveSig]
		int Disconnect( [In] IPin pin );
		[PreserveSig]
		int SetDefaultSyncSource( );
	}
	[ComImport,
	Guid("36B73882-C2C8-11CF-8B46-00805F6CEF60"),
	InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	internal interface IFilterGraph2
	{
		[PreserveSig]
		int AddFilter( [In] IBaseFilter filter, [In, MarshalAs( UnmanagedType.LPWStr )] string name );
		[PreserveSig]
		int RemoveFilter( [In] IBaseFilter filter );
		[PreserveSig]
		int EnumFilters( [Out] out IEnumFilters enumerator );
		[PreserveSig]
		int FindFilterByName( [In, MarshalAs( UnmanagedType.LPWStr )] string name, [Out] out IBaseFilter filter );
		[PreserveSig]
		int ConnectDirect( [In] IPin pinOut, [In] IPin pinIn, [In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int Reconnect( [In] IPin pin );
		[PreserveSig]
		int Disconnect( [In] IPin pin );
		[PreserveSig]
		int SetDefaultSyncSource( );
		[PreserveSig]
		int Connect( [In] IPin pinOut, [In] IPin pinIn );
		[PreserveSig]
		int Render( [In] IPin pinOut );
		[PreserveSig]
		int RenderFile(
			[In, MarshalAs( UnmanagedType.LPWStr )] string file,
			[In, MarshalAs( UnmanagedType.LPWStr )] string playList );
		[PreserveSig]
		int AddSourceFilter(
			[In, MarshalAs( UnmanagedType.LPWStr )] string fileName,
			[In, MarshalAs( UnmanagedType.LPWStr )] string filterName,
			[Out] out IBaseFilter filter );
		[PreserveSig]
		int SetLogFile( IntPtr hFile );
		[PreserveSig]
		int Abort( );
		[PreserveSig]
		int ShouldOperationContinue( );
		[PreserveSig]
		int AddSourceFilterForMoniker(
			[In] IMoniker moniker,
			[In] IBindCtx bindContext,
			[In, MarshalAs( UnmanagedType.LPWStr )] string filterName,
			[Out] out IBaseFilter filter
		);
		[PreserveSig]
		int ReconnectEx(
			[In] IPin pin,
			[In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType
			);
		[PreserveSig]
		int RenderEx(
			[In] IPin outputPin,
			[In] int flags,
			[In] IntPtr context
			);

	}
	[ComImport,
	Guid( "56A868A9-0AD4-11CE-B03A-0020AF0BA770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IGraphBuilder
	{
		[PreserveSig]
		int AddFilter( [In] IBaseFilter filter, [In, MarshalAs( UnmanagedType.LPWStr )] string name );
		[PreserveSig]
		int RemoveFilter( [In] IBaseFilter filter );
		[PreserveSig]
		int EnumFilters( [Out] out IEnumFilters enumerator );
		[PreserveSig]
		int FindFilterByName( [In, MarshalAs( UnmanagedType.LPWStr )] string name, [Out] out IBaseFilter filter );
		[PreserveSig]
		int ConnectDirect( [In] IPin pinOut, [In] IPin pinIn, [In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int Reconnect( [In] IPin pin );
		[PreserveSig]
		int Disconnect( [In] IPin pin );
		[PreserveSig]
		int SetDefaultSyncSource( );
		[PreserveSig]
		int Connect( [In] IPin pinOut, [In] IPin pinIn );
		[PreserveSig]
		int Render( [In] IPin pinOut );
		[PreserveSig]
		int RenderFile(
			[In, MarshalAs( UnmanagedType.LPWStr )] string file,
			[In, MarshalAs( UnmanagedType.LPWStr )] string playList);
		[PreserveSig]
		int AddSourceFilter(
			[In, MarshalAs( UnmanagedType.LPWStr )] string fileName,
			[In, MarshalAs( UnmanagedType.LPWStr )] string filterName,
			[Out] out IBaseFilter filter );
		[PreserveSig]
		int SetLogFile( IntPtr hFile );
		[PreserveSig]
		int Abort( );
		[PreserveSig]
		int ShouldOperationContinue( );
	}
	[ComImport,
	Guid( "56A868B1-0AD4-11CE-B03A-0020AF0BA770" ),
	InterfaceType( ComInterfaceType.InterfaceIsDual )]
	internal interface IMediaControl
	{
		[PreserveSig]
		int Run( );
		[PreserveSig]
		int Pause( );
		[PreserveSig]
		int Stop( );
		[PreserveSig]
		int GetState( int timeout, out int filterState );
		[PreserveSig]
		int RenderFile( string fileName );
		[PreserveSig]
		int AddSourceFilter( [In] string fileName, [Out, MarshalAs( UnmanagedType.IDispatch )] out object filterInfo );
		[PreserveSig]
		int get_FilterCollection(
			[Out, MarshalAs( UnmanagedType.IDispatch )] out object collection );
		[PreserveSig]
		int get_RegFilterCollection(
			[Out, MarshalAs( UnmanagedType.IDispatch )] out object collection );
		[PreserveSig]
		int StopWhenReady( );
	}
	[ComVisible( true ), ComImport,
	Guid( "56a868c0-0ad4-11ce-b03a-0020af0ba770" ),
	InterfaceType( ComInterfaceType.InterfaceIsDual )]
	internal interface IMediaEventEx
	{
		[PreserveSig]
		int GetEventHandle( out IntPtr hEvent );
		[PreserveSig]
		int GetEvent( [Out, MarshalAs( UnmanagedType.I4 )] out DsEvCode lEventCode, [Out] out IntPtr lParam1, [Out] out IntPtr lParam2, int msTimeout );
		[PreserveSig]
		int WaitForCompletion( int msTimeout, [Out] out int pEvCode );
		[PreserveSig]
		int CancelDefaultHandling( int lEvCode );
		[PreserveSig]
		int RestoreDefaultHandling( int lEvCode );
		[PreserveSig]
		int FreeEventParams( [In, MarshalAs( UnmanagedType.I4 )] DsEvCode lEvCode, IntPtr lParam1, IntPtr lParam2 );
		[PreserveSig]
		int SetNotifyWindow( IntPtr hwnd, int lMsg, IntPtr lInstanceData );
		[PreserveSig]
		int SetNotifyFlags( int lNoNotifyFlags );
		[PreserveSig]
		int GetNotifyFlags( out int lplNoNotifyFlags );
	}
	[ComImport, System.Security.SuppressUnmanagedCodeSecurity,
	Guid( "56a86899-0ad4-11ce-b03a-0020af0ba770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IMediaFilter : IPersist
	{
		#region IPersist Methods

		[PreserveSig]
		new int GetClassID(
			[Out] out Guid pClassID );

		#endregion
		[PreserveSig]
		int Stop( );
		[PreserveSig]
		int Pause( );
		[PreserveSig]
		int Run( [In] long tStart );
		[PreserveSig]
		int GetState(
			[In] int dwMilliSecsTimeout,
			[Out] out FilterState filtState );
		[PreserveSig]
		int SetSyncSource( [In] IReferenceClock pClock );
		[PreserveSig]
		int GetSyncSource( [Out] out IReferenceClock pClock );
	}
	[ComImport,
	Guid("0000010c-0000-0000-C000-000000000046"),
	InterfaceType(ComInterfaceType.InterfaceIsDual)]
	internal interface IPersist
	{
		[PreserveSig]
		int GetClassID([Out] out Guid pClassID);
	}
	[ComImport,
	Guid( "56A86891-0AD4-11CE-B03A-0020AF0BA770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IPin
	{
		[PreserveSig]
		int Connect( [In] IPin receivePin, [In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int ReceiveConnection( [In] IPin receivePin, [In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int Disconnect( );
		[PreserveSig]
		int ConnectedTo( [Out] out IPin pin );
		[PreserveSig]
		int ConnectionMediaType( [Out, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int QueryPinInfo( [Out] out PinInfo pinInfo );
		[PreserveSig]
		int QueryDirection( out PinDirection pinDirection );
		[PreserveSig]
		int QueryId( [Out, MarshalAs( UnmanagedType.LPWStr )] out string id );
		[PreserveSig]
		int QueryAccept( [In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int EnumMediaTypes( [Out] out IEnumMediaTypes enumMediaTypes );
		[PreserveSig]
		int QueryInternalConnections( IntPtr apPin, [In, Out] ref int nPin );
		[PreserveSig]
		int EndOfStream( );
		[PreserveSig]
		int BeginFlush( );
		[PreserveSig]
		int EndFlush( );
		[PreserveSig]
		int NewSegment(
			long start,
			long stop,
			double rate );
	}
	[ComImport,
	Guid( "55272A00-42CB-11CE-8135-00AA004BB851" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IPropertyBag
	{
		[PreserveSig]
		int Read(
			[In, MarshalAs( UnmanagedType.LPWStr )] string propertyName,
			[In, Out, MarshalAs( UnmanagedType.Struct )] ref object pVar,
			[In] IntPtr pErrorLog );
		[PreserveSig]
		int Write(
			[In, MarshalAs( UnmanagedType.LPWStr )] string propertyName,
			[In, MarshalAs( UnmanagedType.Struct )] ref object pVar );
	}
	[ComImport, System.Security.SuppressUnmanagedCodeSecurity,
	Guid( "56a86897-0ad4-11ce-b03a-0020af0ba770" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface IReferenceClock
	{
		[PreserveSig]
		int GetTime( [Out] out long pTime );
		[PreserveSig]
		int AdviseTime(
			[In] long baseTime,
			[In] long streamTime,
			[In] IntPtr hEvent,
			[Out] out int pdwAdviseCookie );
		[PreserveSig]
		int AdvisePeriodic(
			[In] long startTime,
			[In] long periodTime,
			[In] IntPtr hSemaphore,
			[Out] out int pdwAdviseCookie );
		[PreserveSig]
		int Unadvise( [In] int dwAdviseCookie );
	}
	[ComImport,
	Guid("6B652FFF-11FE-4FCE-92AD-0266B5D7C78F"),
	InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	internal interface ISampleGrabber
	{
		[PreserveSig]
		int SetOneShot( [In, MarshalAs( UnmanagedType.Bool )] bool oneShot );
		[PreserveSig]
		int SetMediaType( [In, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int GetConnectedMediaType( [Out, MarshalAs( UnmanagedType.LPStruct )] AMMediaType mediaType );
		[PreserveSig]
		int SetBufferSamples( [In, MarshalAs( UnmanagedType.Bool )] bool bufferThem );
		[PreserveSig]
		int GetCurrentBuffer( ref int bufferSize, IntPtr buffer );
		[PreserveSig]
		int GetCurrentSample( IntPtr sample );
		[PreserveSig]
		int SetCallback( ISampleGrabberCB callback, int whichMethodToCallback );
	}
	[ComImport,
	Guid("0579154A-2B53-4994-B0D0-E773148EFF85"),
	InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	internal interface ISampleGrabberCB
	{
		[PreserveSig]
		int SampleCB( double sampleTime, IntPtr sample );
		[PreserveSig]
		int BufferCB( double sampleTime, IntPtr buffer, int bufferLen );
	}
	[ComImport,
	Guid( "B196B28B-BAB4-101A-B69C-00AA00341D07" ),
	InterfaceType( ComInterfaceType.InterfaceIsIUnknown )]
	internal interface ISpecifyPropertyPages
	{
		[PreserveSig]
		int GetPages( out CAUUID pPages );
	}
	[ComImport,
	Guid("56A868B4-0AD4-11CE-B03A-0020AF0BA770"),
	InterfaceType(ComInterfaceType.InterfaceIsDual)]
	internal interface IVideoWindow
	{
		[PreserveSig]
		int put_Caption( string caption );
		[PreserveSig]
		int get_Caption( [Out] out string caption );
		[PreserveSig]
		int put_WindowStyle( int windowStyle );
		[PreserveSig]
		int get_WindowStyle( out int windowStyle );
		[PreserveSig]
		int put_WindowStyleEx( int windowStyleEx );
		[PreserveSig]
		int get_WindowStyleEx( out int windowStyleEx );
		[PreserveSig]
		int put_AutoShow( [In, MarshalAs( UnmanagedType.Bool )] bool autoShow );
		[PreserveSig]
		int get_AutoShow( [Out, MarshalAs( UnmanagedType.Bool )] out bool autoShow );
		[PreserveSig]
		int put_WindowState( int windowState );
		[PreserveSig]
		int get_WindowState( out int windowState );
		[PreserveSig]
		int put_BackgroundPalette( [In, MarshalAs( UnmanagedType.Bool )] bool backgroundPalette );
		[PreserveSig]
		int get_BackgroundPalette( [Out, MarshalAs( UnmanagedType.Bool )] out bool backgroundPalette );
		[PreserveSig]
		int put_Visible( [In, MarshalAs( UnmanagedType.Bool )] bool visible );
		[PreserveSig]
		int get_Visible( [Out, MarshalAs( UnmanagedType.Bool )] out bool visible );
		[PreserveSig]
		int put_Left( int left );
		[PreserveSig]
		int get_Left( out int left );
		[PreserveSig]
		int put_Width( int width );
		[PreserveSig]
		int get_Width( out int width );
		[PreserveSig]
		int put_Top( int top );
		[PreserveSig]
		int get_Top( out int top );
		[PreserveSig]
		int put_Height( int height );
		[PreserveSig]
		int get_Height( out int height );
		[PreserveSig]
		int put_Owner( IntPtr owner );
		[PreserveSig]
		int get_Owner( out IntPtr owner );
		[PreserveSig]
		int put_MessageDrain( IntPtr drain );
		[PreserveSig]
		int get_MessageDrain( out IntPtr drain );
		[PreserveSig]
		int get_BorderColor( out int color );
		[PreserveSig]
		int put_BorderColor( int color );
		[PreserveSig]
		int get_FullScreenMode(
			[Out, MarshalAs( UnmanagedType.Bool )] out bool fullScreenMode );
		[PreserveSig]
		int put_FullScreenMode( [In, MarshalAs( UnmanagedType.Bool )] bool fullScreenMode );
		[PreserveSig]
		int SetWindowForeground( int focus );
		[PreserveSig]
		int NotifyOwnerMessage( IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam );
		[PreserveSig]
		int SetWindowPosition( int left, int top, int width, int height );
		[PreserveSig]
		int GetWindowPosition( out int left, out int top, out int width, out int height );
		[PreserveSig]
		int GetMinIdealImageSize( out int width, out int height );
		[PreserveSig]
		int GetMaxIdealImageSize( out int width, out int height );
		[PreserveSig]
		int GetRestorePosition( out int left, out int top, out int width, out int height );
		[PreserveSig]
		int HideCursor( [In, MarshalAs( UnmanagedType.Bool )] bool hideCursor );
		[PreserveSig]
		int IsCursorHidden( [Out, MarshalAs( UnmanagedType.Bool )] out bool hideCursor );
	}
	[ComVisible( false )]
	internal enum PinDirection
	{
		Input,
		Output
	}
	[ComVisible( false ),
	StructLayout( LayoutKind.Sequential )]
	internal class AMMediaType : IDisposable
	{
		public Guid MajorType;
		public Guid SubType;
		[MarshalAs( UnmanagedType.Bool )]
		public bool FixedSizeSamples = true;
		[MarshalAs( UnmanagedType.Bool )]
		public bool TemporalCompression;
		public int SampleSize = 1;
		public Guid FormatType;
		public IntPtr unkPtr;
		public int FormatSize;
		public IntPtr FormatPtr;
		~AMMediaType( )
		{
			Dispose( false );
		}
		public void Dispose( )
		{
			Dispose( true );
			GC.SuppressFinalize( this );
		}
		protected virtual void Dispose( bool disposing )
		{
			if ( ( FormatSize != 0 ) && ( FormatPtr != IntPtr.Zero ) )
			{
				Marshal.FreeCoTaskMem( FormatPtr );
				FormatSize = 0;
			}

			if ( unkPtr != IntPtr.Zero )
			{
				Marshal.Release( unkPtr );
				unkPtr = IntPtr.Zero;
			}
		}
	}
	[ComVisible( false ),
	StructLayout( LayoutKind.Sequential, Pack = 1, CharSet = CharSet.Unicode )]
	internal struct PinInfo
	{
		public IBaseFilter Filter;
		public PinDirection Direction;
		[MarshalAs( UnmanagedType.ByValTStr, SizeConst = 128 )]
		public string Name;
	}
	[ComVisible( false ),
	StructLayout( LayoutKind.Sequential, Pack = 1, CharSet = CharSet.Unicode )]
	internal struct FilterInfo
	{
		[MarshalAs( UnmanagedType.ByValTStr, SizeConst = 128 )]
		public string Name;
		public IFilterGraph FilterGraph;
	}
	[ComVisible( false ),
	StructLayout( LayoutKind.Sequential )]
	internal struct VideoInfoHeader
	{
		public RECT SrcRect;
		public RECT TargetRect;
		public int BitRate;
		public int BitErrorRate;
		public long AverageTimePerFrame;
		public BitmapInfoHeader BmiHeader;
	}
	[ComVisible( false ),
	StructLayout( LayoutKind.Sequential )]
	internal struct VideoInfoHeader2
	{
		public RECT SrcRect;
		public RECT TargetRect;
		public int BitRate;
		public int BitErrorRate;
		public long AverageTimePerFrame;
		public int InterlaceFlags;
		public int CopyProtectFlags;
		public int PictAspectRatioX;
		public int PictAspectRatioY;
		public int Reserved1;
		public int Reserved2;
		public BitmapInfoHeader BmiHeader;
	}
	[ComVisible( false ),
	StructLayout( LayoutKind.Sequential, Pack = 2 )]
	internal struct BitmapInfoHeader
	{
		public int Size;
		public int Width;
		public int Height;
		public short Planes;
		public short BitCount;
		public int Compression;
		public int ImageSize;
		public int XPelsPerMeter;
		public int YPelsPerMeter;
		public int ColorsUsed;
		public int ColorsImportant;
	}
	[ComVisible( false ),
	StructLayout( LayoutKind.Sequential )]
	internal struct RECT
	{
		public int Left;
		public int Top;
		public int Right;
		public int Bottom;
	}
	[ComVisible( false ),
	StructLayout( LayoutKind.Sequential )]
	internal struct CAUUID
	{
		public int cElems;
		public IntPtr pElems;
		public Guid[] ToGuidArray( )
		{
			Guid[] retval = new Guid[cElems];

			for ( int i = 0; i < cElems; i++ )
			{
				IntPtr ptr = new IntPtr( pElems.ToInt64( ) + i * Marshal.SizeOf( typeof( Guid ) ) );
				retval[i] = (Guid) Marshal.PtrToStructure( ptr, typeof( Guid ) );
			}

			return retval;
		}
	}
	internal enum DsEvCode
	{
		None,
		Complete   = 0x01,
		DeviceLost = 0x1F,
	}

	[Flags, ComVisible( false )]
	internal enum AnalogVideoStandard
	{
		None		= 0x00000000,
		NTSC_M	  = 0x00000001,
		NTSC_M_J	= 0x00000002,
		NTSC_433	= 0x00000004,
		PAL_B	   = 0x00000010,
		PAL_D	   = 0x00000020,
		PAL_G	   = 0x00000040,
		PAL_H	   = 0x00000080,
		PAL_I	   = 0x00000100,
		PAL_M	   = 0x00000200,
		PAL_N	   = 0x00000400,
		PAL_60	  = 0x00000800,
		SECAM_B	 = 0x00001000,
		SECAM_D	 = 0x00002000,
		SECAM_G	 = 0x00004000,
		SECAM_H	 = 0x00008000,
		SECAM_K	 = 0x00010000,
		SECAM_K1	= 0x00020000,
		SECAM_L	 = 0x00040000,
		SECAM_L1	= 0x00080000,
		PAL_N_COMBO = 0x00100000
	}

	[Flags, ComVisible( false )]
	internal enum VideoControlFlags
	{
		FlipHorizontal		= 0x0001,
		FlipVertical		  = 0x0002,
		ExternalTriggerEnable = 0x0004,
		Trigger			   = 0x0008
	}

	[StructLayout( LayoutKind.Sequential ), ComVisible( false )]
	internal class VideoStreamConfigCaps
	{
		public Guid				 Guid;
		public AnalogVideoStandard  VideoStandard;
		public Size				 InputSize;
		public Size				 MinCroppingSize;
		public Size				 MaxCroppingSize;
		public int				  CropGranularityX;
		public int				  CropGranularityY;
		public int				  CropAlignX;
		public int				  CropAlignY;
		public Size				 MinOutputSize;
		public Size				 MaxOutputSize;
		public int				  OutputGranularityX;
		public int				  OutputGranularityY;
		public int				  StretchTapsX;
		public int				  StretchTapsY;
		public int				  ShrinkTapsX;
		public int				  ShrinkTapsY;
		public long				 MinFrameInterval;
		public long				 MaxFrameInterval;
		public int				  MinBitsPerSecond;
		public int				  MaxBitsPerSecond;
	}
	internal enum FilterState
	{
		State_Stopped,
		State_Paused,
		State_Running
	}
	internal static class Tools
	{
		public static IPin GetPin( IBaseFilter filter, PinDirection dir, int num )
		{
			IPin[] pin = new IPin[1];
			IEnumPins pinsEnum = null;
			if ( filter.EnumPins( out pinsEnum ) == 0 )
			{
				PinDirection pinDir;
				int n;

				try
				{
					while ( pinsEnum.Next( 1, pin, out n ) == 0 )
					{
						pin[0].QueryDirection( out pinDir );

						if ( pinDir == dir )
						{
							if ( num == 0 )
								return pin[0];
							num--;
						}

						Marshal.ReleaseComObject( pin[0] );
						pin[0] = null;
					}
				}
				finally
				{
					Marshal.ReleaseComObject( pinsEnum );
				}
			}
			return null;
		}
		public static IPin GetInPin( IBaseFilter filter, int num )
		{
			return GetPin( filter, PinDirection.Input, num );
		}
		public static IPin GetOutPin( IBaseFilter filter, int num )
		{
			return GetPin( filter, PinDirection.Output, num );
		}
	}
	[ComVisible( false )]
	static internal class Clsid
	{
		public static readonly Guid SystemDeviceEnum =
			new Guid( 0x62BE5D10, 0x60EB, 0x11D0, 0xBD, 0x3B, 0x00, 0xA0, 0xC9, 0x11, 0xCE, 0x86 );
		public static readonly Guid FilterGraph =
			new Guid( 0xE436EBB3, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid SampleGrabber =
			new Guid( 0xC1F400A0, 0x3F08, 0x11D3, 0x9F, 0x0B, 0x00, 0x60, 0x08, 0x03, 0x9E, 0x37 );
		public static readonly Guid CaptureGraphBuilder2 =
			new Guid( 0xBF87B6E1, 0x8C27, 0x11D0, 0xB3, 0xF0, 0x00, 0xAA, 0x00, 0x37, 0x61, 0xC5 );
		public static readonly Guid AsyncReader =
			new Guid( 0xE436EBB5, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
	}
	[ComVisible( false )]
	static internal class FormatType
	{
		public static readonly Guid VideoInfo =
			new Guid( 0x05589F80, 0xC356, 0x11CE, 0xBF, 0x01, 0x00, 0xAA, 0x00, 0x55, 0x59, 0x5A );
		public static readonly Guid VideoInfo2 =
			new Guid( 0xf72A76A0, 0xEB0A, 0x11D0, 0xAC, 0xE4, 0x00, 0x00, 0xC0, 0xCC, 0x16, 0xBA );
	}
	[ComVisible( false )]
	static internal class MediaType
	{
		public static readonly Guid Video =
			new Guid( 0x73646976, 0x0000, 0x0010, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 );
		public static readonly Guid Interleaved =
			new Guid( 0x73766169, 0x0000, 0x0010, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 );
		public static readonly Guid Audio =
			new Guid( 0x73647561, 0x0000, 0x0010, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 );
		public static readonly Guid Text =
			new Guid( 0x73747874, 0x0000, 0x0010, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 );
		public static readonly Guid Stream =
			new Guid( 0xE436EB83, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
	}
	[ComVisible( false )]
	static internal class MediaSubType
	{
		public static readonly Guid YUYV =
			new Guid( 0x56595559, 0x0000, 0x0010, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 );
		public static readonly Guid IYUV =
			new Guid( 0x56555949, 0x0000, 0x0010, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 );
		public static readonly Guid DVSD =
			new Guid( 0x44535644, 0x0000, 0x0010, 0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71 );
		public static readonly Guid RGB1 =
			new Guid( 0xE436EB78, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid RGB4 =
			new Guid( 0xE436EB79, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid RGB8 =
			new Guid( 0xE436EB7A, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid RGB565 =
			new Guid( 0xE436EB7B, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid RGB555 =
			new Guid( 0xE436EB7C, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid RGB24 =
			new Guid( 0xE436Eb7D, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid RGB32 =
			new Guid( 0xE436EB7E, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid Avi =
			new Guid( 0xE436EB88, 0x524F, 0x11CE, 0x9F, 0x53, 0x00, 0x20, 0xAF, 0x0B, 0xA7, 0x70 );
		public static readonly Guid Asf =
			new Guid( 0x3DB80F90, 0x9412, 0x11D1, 0xAD, 0xED, 0x00, 0x00, 0xF8, 0x75, 0x4B, 0x99 );
		public static readonly Guid MJpeg =
			new Guid( 0x47504A4D, 0x0000, 0x0010, 0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71 );
	}
	[ComVisible( false )]
	static internal class PinCategory
	{
		public static readonly Guid Capture =
			new Guid( 0xFB6C4281, 0x0353, 0x11D1, 0x90, 0x5F, 0x00, 0x00, 0xC0, 0xCC, 0x16, 0xBA );
		public static readonly Guid StillImage =
			new Guid( 0xFB6C428A, 0x0353, 0x11D1, 0x90, 0x5F, 0x00, 0x00, 0xC0, 0xCC, 0x16, 0xBA );
	}
	[ComVisible( false )]
	static internal class FindDirection
	{
		public static readonly Guid UpstreamOnly =
			new Guid( 0xAC798BE0, 0x98E3, 0x11D1, 0xB3, 0xF1, 0x00, 0xAA, 0x00, 0x37, 0x61, 0xC5 );
		public static readonly Guid DownstreamOnly =
			new Guid( 0xAC798BE1, 0x98E3, 0x11D1, 0xB3, 0xF1, 0x00, 0xAA, 0x00, 0x37, 0x61, 0xC5 );
	}
	internal static class Win32
	{
		[DllImport( "ole32.dll" )]
		public static extern
		int CreateBindCtx( int reserved, out IBindCtx ppbc );
		[DllImport( "ole32.dll", CharSet = CharSet.Unicode )]
		public static extern
		int MkParseDisplayName( IBindCtx pbc, string szUserName,
			ref int pchEaten, out IMoniker ppmk );
		[DllImport( "ntdll.dll", CallingConvention = CallingConvention.Cdecl )]
		public static unsafe extern int memcpy(
			byte* dst,
			byte* src,
			int count );
		[DllImport( "oleaut32.dll" )]
		public static extern int OleCreatePropertyFrame(
			IntPtr hwndOwner,
			int x,
			int y,
			[MarshalAs( UnmanagedType.LPWStr )] string caption,
			int cObjects,
			[MarshalAs( UnmanagedType.Interface, ArraySubType = UnmanagedType.IUnknown )] 
			ref object ppUnk,
			int cPages,
			IntPtr lpPageClsID,
			int lcid,
			int dwReserved,
			IntPtr lpvReserved );
	}
	// these were from AForge.Video.DirectShow
	public enum CameraControlProperty
	{
		Pan = 0,
		Tilt,
		Roll,
		Zoom,
		Exposure,
		Iris,
		Focus
	}
	[Flags]
	public enum CameraControlFlags
	{
		None = 0x0,
		Auto = 0x0001,
		Manual = 0x0002
	}
	public enum PhysicalConnectorType
	{
		Default = 0,
		VideoTuner = 1,
		VideoComposite,
		VideoSVideo,
		VideoRGB,
		VideoYRYBY,
		VideoSerialDigital,
		VideoParallelDigital,
		VideoSCSI,
		VideoAUX,
		Video1394,
		VideoUSB,
		VideoDecoder,
		VideoEncoder,
		VideoSCART,
		VideoBlack,
		AudioTuner = 4096,
		AudioLine,
		AudioMic,
		AudioAESDigital,
		AudioSPDIFDigital,
		AudioSCSI,
		AudioAUX,
		Audio1394,
		AudioUSB,
		AudioDecoder
	}
}
"@

sc "cam.cs" $cam -en utf8
[IO.File]::WriteAllBytes("cam.res", @(0,0,0,0,8,0,0,0))
C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe /out:$pwd\cam.dll /r:"System.Drawing.dll" /t:library /win32res:cam.res $pwd\cam.cs /unsafe /nowin32manifest /nologo
ri cam.cs
ri cam.res