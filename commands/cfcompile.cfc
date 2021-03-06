/**
 * compiles CFML code
 * .
 * Examples
 * {code:bash}
 * compile /path/to/folder
 * {code}
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	
	property inject="compiler@cfml-compiler" name="compiler";

	/**
	* @sourcePath A file or directory to compile
	* @destPath The destination of the compiled file(s)
	* @overwrite Allow overwrite without prompting
	* @cfengine The cfml engine version to compile for
	* @extensionFilter Pipe-delimited list of paths to compile. ex. *.cfc|*.cfm
	**/
	function run( sourcePath="./", string destPath="", boolean overwrite="false", string cfengine="", string extensionFilter="*.cfm|*.cfc" )  {
		

		arguments.sourcePath = fileSystemUtil.resolvePath(arguments.sourcePath);
		if (!directoryExists(arguments.sourcePath) && !fileExists(arguments.sourcePath))  {
			error("The source path was not a directory or file.");
		}

		if (arguments.destPath == "") {
			arguments.destPath = arguments.sourcePath;
		} else {
			arguments.destPath = fileSystemUtil.resolvePath(arguments.destPath);
		}

		if (!arguments.overwrite) {
			
			if (arguments.destPath == arguments.sourcePath) {
				local.allowOverwrite = ask(message="The source code will be overwritten, type: OK if you want to continue: ");
				if (local.allowOverwrite != "OK") {
					print.redLine("10-4, exiting");
					return;
				}
			}
		}
		
		
		

		try {
			local.accessKey = reReplace(generateSecretKey("AES"), "[^a-zA-Z0-9]", randRange(0,9), "ALL");
			local.compilerObj = compiler;
			local.up = false;
			if (len(arguments.cfengine) || 1==1) {
				if (fileExists(arguments.sourcePath & "/__cfml-compiler/")) {
					throw(message="Compiler folder already exists in: #arguments.sourcePath#");
				}
				directoryCopy(getCompilerRoot(), arguments.sourcePath & "/__cfml-compiler/")
				local.serverArgs = {
					name="cfml-compiler-server",
					port=50505,
					host="127.0.0.1",
					saveSettings=false,
					JVMArgs="-Dcfmlcompilerkey=" & local.accessKey,
					cfengine=arguments.cfengine,
					openbrowser=false,
					directory=arguments.sourcePath
				};
				command( "server start" )
    			.params( argumentCollection=local.serverArgs )
    			.run();
    			
    			for (local.i =0;i<20;i++) {
    				sleep(1000);
    				try {
    					local.compilerObj = createObject("webservice", "http://127.0.0.1:50505/__cfml-compiler/compiler.cfc?wsdl");
    					if (local.compilerObj.serviceUp() == "UP") {
    						local.up = true;
    						break;
    					}
    					print.yellowLine("Waiting for server to start: #i#/20");
    				} catch (any err) {
    					//try again
    				}
    			}
    			
    		} else {
    			createObject("java", "java.lang.System").setProperty("cfmlcompilerkey", local.accessKey);
    			local.up = true;
    		}
    		if (!local.up) {
    			error("Unable to start compiler server after 20 seconds.");
			} else {
				print.greenLine("Starting compilation of: #arguments.sourcePath#");
				print.greenLine("Destination: #arguments.destPath#");
    			local.result = local.compilerObj.compiler(source=arguments.sourcePath, dest=arguments.destPath, accessKey=local.accessKey, extensionFilter=arguments.extensionFilter );
    			if (local.result == "done") {
    				print.greenLine("Finished!");
    			} else {
    				error("Unexpected Result: #local.result#");
    			}

			}
    		


		} catch (any err) {
			if (err.message contains "exit code (1)") {
				setExitCode( 1 );
			} else {
				rethrow;
			}
			
		} finally {
			
			if (len(arguments.cfengine) || 1 == 1) {
				command( "server stop" )
    				.params( name="cfml-compiler-server", forget=true )
    				.run();	
    			
    			sleep(100);
    			var tempCompileDirSrc = arguments.sourcePath & "/__cfml-compiler/";
    			var tempCompileDirDest = arguments.destPath & "/__cfml-compiler/";
    			
    			if (directoryExists( tempCompileDirSrc )) {
					directoryDelete( tempCompileDirSrc, true);
				}
				if ( tempCompileDirSrc != tempCompileDirDest && directoryExists( tempCompileDirDest )) {
					directoryDelete( tempCompileDirDest, true);
				}
			}
			
		}
		
		
	}




	private function getCompilerRoot() {
		return expandPath( '/cfml-compiler/models/' );
	}

	private function getCompilerFilePath() {
		return expandPath( '/cfml-compiler/models/compiler.cfc' );
		return replace(p, "commands/compile.cfc", "models/compiler.cfc"); 
	}
	

}