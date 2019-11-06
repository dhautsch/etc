import java.io.InputStream;
import java.io.OutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.security.KeyStore;
import java.util.List;
import java.util.Properties;
import java.nio.file.Paths;
import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.util.TimeZone;
import java.text.SimpleDateFormat;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.net.ssl.SSLContext;

import org.apache.log4j.Logger;
import org.apache.http.conn.ssl.SSLConnectionSocketFactory;
import org.apache.http.conn.ssl.TrustSelfSignedStrategy;
import org.apache.http.ssl.SSLContexts;

import com.amazonaws.AmazonServiceException;
import com.amazonaws.SdkClientException;
import com.amazonaws.ClientConfiguration;
import com.amazonaws.Protocol;
import com.amazonaws.auth.AWSStaticCredentialsProvider;
import com.amazonaws.auth.BasicSessionCredentials;
import com.amazonaws.services.kms.AWSKMS;
import com.amazonaws.services.lambda.AWSLambda;
import com.amazonaws.services.lambda.AWSLambdaClientBuilder;
import com.amazonaws.services.lambda.model.InvokeRequest;
import com.amazonaws.services.lambda.model.InvokeResult;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.Bucket;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.amazonaws.services.s3.model.GetObjectRequest;
import com.amazonaws.services.s3.model.S3Object;
import com.amazonaws.services.s3.model.S3ObjectSummary;
import com.amazonaws.services.s3.model.SSEAwsKeyManagementParams;
import com.amazonaws.services.s3.model.ListObjectsV2Request;
import com.amazonaws.services.s3.model.ListObjectsV2Result;

import com.amazonaws.services.s3.model.CSVInput;
import com.amazonaws.services.s3.model.CSVOutput;
import com.amazonaws.services.s3.model.JSONType;
import com.amazonaws.services.s3.model.JSONInput;
import com.amazonaws.services.s3.model.JSONOutput;
import com.amazonaws.services.s3.model.CompressionType;
import com.amazonaws.services.s3.model.ExpressionType;
import com.amazonaws.services.s3.model.InputSerialization;
import com.amazonaws.services.s3.model.OutputSerialization;
import com.amazonaws.services.s3.model.SelectObjectContentEvent;
import com.amazonaws.services.s3.model.SelectObjectContentEventVisitor;
import com.amazonaws.services.s3.model.SelectObjectContentRequest;
import com.amazonaws.services.s3.model.SelectObjectContentResult;
import static com.amazonaws.util.IOUtils.copy;
import static com.amazonaws.util.IOUtils.toByteArray;

import java.util.concurrent.atomic.AtomicBoolean;
import com.yoyodyne.access.sts.AWSFederationAccess;
import com.fasterxml.jackson.databind.ObjectMapper;

public class Driver {

	final static Logger _logger = Logger.getLogger(Driver.class);
	final static String _regionEnvVar  = "AWS_REGION";
	final static String _regionFromEnv = System.getenv(_regionEnvVar);
	final static String _defaultRegion = "us-east-1";

	static BasicSessionCredentials _sessionCredentials = null;
	static ClientConfiguration _clientConf = null;
	protected AWSKMS kms = null;

	public static void main(String[] args) {
		int exitCode_ = 1;
		InputStream is_ = null;
		String bucketName_ = null;
		String bucketObjKey_ = null;
		String listBucketPrefix_ = null;
		String listBucketDelimiter_ = null;
		int listBucketMaxKeys_ = 0;
		String keyARN_ = System.getenv("AWS_KMS_KEYID");
		String[] _awsCredData = {
				  "AWS_ACCESS_KEY_ID", 
				  "AWS_SECRET_ACCESS_KEY", 
				  "AWS_SESSION_TOKEN" 
				};
		String _awsConnection = "AWS_CONN";
		SimpleDateFormat dtFmt_ = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");

		dtFmt_.setTimeZone(TimeZone.getTimeZone("UTC"));

		for (int i_ = 0; i_ < args.length; i_++) {
			_logger.info(String.format("ARG[%d]='%s'", i_, args[i_]));
		}

		_awsConnection = System.getenv(_awsConnection);
		if (_awsConnection != null) {
			Matcher m_ = Pattern.compile("^([^/]+)/([^@]+)@(.*)").matcher(_awsConnection);

			if (m_.find()) {
				for (int i_ = 0; i_ < _awsCredData.length; i_++) {
					_awsCredData[i_] = m_.group(i_+1);
				}
			}
			else {
				_logger.fatal("AWS_CONN FORMAT NOT USER/PASS@ROLE");
				System.exit(exitCode_);
			}
		}
		else {
			for (int i_ = 0; i_ < _awsCredData.length; i_++) {
				String env_ = _awsCredData[i_];
				String envValue_ = System.getenv(env_);
				if (envValue_ == null) {
					_logger.fatal("UNDEFINED ENV VAR : " + env_);
					System.exit(exitCode_);
				}
				else {
					_awsCredData[i_] = envValue_;
				}
			}
		}

		if (args.length < 1
				|| (args[0].equals("S3_GET_OBJ")
						|| args[0].equals("GET_ACCESS_KEYS")
						|| args[0].equals("S3_PUT_OBJ")
						|| args[0].equals("LAMBDA")
						|| args[0].equals("S3_CSV_QUERY")
						|| args[0].equals("S3_JSON_QUERY_DOCUMENT")
						|| args[0].equals("S3_JSON_QUERY_LINES")
						|| args[0].equals("S3_GZIPPED_CSV_QUERY")
						|| args[0].equals("S3_GZIPPED_JSON_QUERY_DOCUMENT")
						|| args[0].equals("S3_GZIPPED_JSON_QUERY_LINES")
						|| args[0].equals("S3_LIST_BUCKETS")
						|| args[0].equals("S3_LIST_BUCKET")) == false
				|| args[0].equals("S3_GET_OBJ") && args.length != 3
				|| args[0].equals("S3_PUT_OBJ") && args.length != 3
				|| args[0].equals("LAMBDA") && args.length != 4
				|| args[0].indexOf("QUERY") > -1 && args.length != 4
				|| args[0].equals("GET_ACCESS_KEYS") && args.length != 1
				|| args[0].equals("S3_LIST_BUCKETS") && args.length != 1
				|| args[0].equals("S3_LIST_BUCKET") && args.length < 2 && Paths.get(args[1]).getNameCount() == 1
				|| args[0].equals("S3_PUT_OBJ") && Paths.get(args[2]).getNameCount() < 3
				|| args[0].equals("S3_PUT_OBJ") && Paths.get(args[1]).getNameCount() < 3 && !args[1].equals("-")
				|| args[0].equals("LAMBDA") && !args[2].equals("-") && !Paths.get(args[2]).toFile().exists()
				|| args[0].equals("LAMBDA") && !args[3].equals("-") && Paths.get(args[3]).getNameCount() < 3
				) {
			_logger.fatal("USAGE : jar GET_ACCESS_KEYS");
			_logger.fatal("USAGE : jar S3_PUT_OBJ (INFILE_PATH|-) /BUCKET/OBJ_KEY");
			_logger.fatal("USAGE : jar S3_GET_OBJ /BUCKET/OBJ_KEY (OUTFILE_PATH|-)");
			_logger.fatal("USAGE : jar LAMBDA     function (JSON_FILE_PATH|-) (OUTFILE_PATH|-)");
			_logger.fatal("USAGE : jar S3_LIST_BUCKETS");
			_logger.fatal("USAGE : jar S3_LIST_BUCKET /BUCKET [PREFIX DELIMITER MAX_CNT]");
			_logger.fatal("USAGE : jar S3_[GZIPPED_]CSV_QUERY /BUCKET/OBJ_KEY (OUTFILE_PATH|-) (QUERY_FILE_PATH|-)");
			_logger.fatal("USAGE : jar S3_[GZIPPED_]JSON_QUERY_(DOCUMENT|LINES) /BUCKET/OBJ_KEY (OUTFILE_PATH|-) (QUERY_FILE_PATH|-)");
			_logger.fatal("");
			_logger.fatal("ENV AWS_CONN required or AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN");
			_logger.fatal("ENV AWS_CONN format is user/pass@AWS_ROLE");
			_logger.fatal("");
			_logger.fatal("OPTIONAL ENV AWS_KMS_KEYID for encryption");
			_logger.fatal(String.format("OPTIONAL ENV %s defaults to %s", _regionEnvVar, _defaultRegion));
			_logger.fatal("");
			_logger.fatal("For JSON LINES query files");
			_logger.fatal("{\042first\042 : \042Fred\042, \042last\042 : \042Flintstone\042 }");
			_logger.fatal("{\042first\042 : \042Wilma\042, \042last\042 : \042Flintstone\042 }");
			_logger.fatal("{\042first\042 : \042Pebbles\042, \042last\042 : \042Flintstone\042 }");
			_logger.fatal("{\042first\042 : \042Barney\042, \042last\042 : \042Rubble\042 }");
			_logger.fatal("{\042first\042 : \042Betty\042, \042last\042 : \042Rubble\042 }");
			_logger.fatal("{\042first\042 : \042BamBam\042, \042last\042 : \042Rubble\042 }");
			_logger.fatal("Use Query: select s.* from s3object s where s.\042last\042 = 'Flintstone'");
			_logger.fatal("");
			_logger.fatal("For JSON DOCUMENT query files");
			_logger.fatal("{\042name\042: \042Susan Smith\042,");
			_logger.fatal("\042org\042: \042engineering\042,");
			_logger.fatal("\042projects\042:");
			_logger.fatal("  [");
			_logger.fatal("    {\042project_name\042:\042project1\042, \042completed\042:false},");
			_logger.fatal("    {\042project_name\042:\042project2\042, \042completed\042:true}");
			_logger.fatal("  ]");
			_logger.fatal("}");
			_logger.fatal("Use Query: Select s.projects[0].project_name from S3Object s");
			_logger.fatal("");
			_logger.fatal("For CSV query files");
			_logger.fatal("Fred,Flintstone");
			_logger.fatal("Wilma,Flintstore");
			_logger.fatal("Betty,Rubble");
			_logger.fatal("Barney,Rubble");
			_logger.fatal("Use Query: select * from s3object s where s._2 = 'Flintstone'");

			System.exit(exitCode_);;
		}

		_logger.info(String.format("%s=%s", _regionEnvVar, _regionFromEnv == null ? _defaultRegion : _regionFromEnv));

		if (args[0].equals("S3_PUT_OBJ")) {
			bucketName_ = Paths.get(args[2]).getName(0).toString();
			bucketObjKey_ = Paths.get(args[2]).subpath(1, Paths.get(args[2]).getNameCount()).toString().replace('\\', '/');
		} else if (args[0].equals("S3_GET_OBJ")) {
			bucketName_ = Paths.get(args[1]).getName(0).toString();
			bucketObjKey_ = Paths.get(args[1]).subpath(1, Paths.get(args[1]).getNameCount()).toString().replace('\\', '/');;
		} else if (args[0].indexOf("QUERY") > -1) {
			bucketName_ = Paths.get(args[1]).getName(0).toString();
			bucketObjKey_ = Paths.get(args[1]).subpath(1, Paths.get(args[1]).getNameCount()).toString().replace('\\', '/');;
		} else if (args[0].equals("S3_LIST_BUCKET")) {
			bucketName_ = Paths.get(args[1]).getName(0).toString();

			if (args.length > 2) {
				listBucketPrefix_ = args[2];
				_logger.info(String.format("LIST_BUCKET_PREFIX='%s'", listBucketPrefix_));
			}

			if (args.length > 3) {
				listBucketDelimiter_ = args[3];
				_logger.info(String.format("LIST_BUCKET_DELIMITER='%s'", listBucketDelimiter_));
			}

			if (args.length > 4) {
				listBucketMaxKeys_ = Integer.parseInt(args[4]);
				_logger.info(String.format("LIST_BUCKET_MAX_KEYS='%d'", listBucketMaxKeys_));
			}
		}

		if (bucketName_ != null) {
			_logger.info(String.format("AWS_BUCKET='%s'", bucketName_));
		}

		if (bucketObjKey_ != null) {
			_logger.info(String.format("AWS_BUCKET_OBJ_KEY='%s'", bucketObjKey_));

			if (keyARN_ == null) {
				_logger.info("MISSING ENV{AWS_ENCRYPTION_KMS_KEYID} KMS ENCRYPTION DISABLED");
			} else {
				_logger.info(String.format("AWS_ENCRYPTION_KMS_KEYID='%s'", keyARN_));
			}
		}

		try {
			if (_awsConnection != null) {
				initConnectionFromFederation(_awsCredData[0], _awsCredData[1], _awsCredData[2]);
			}
			else {
				initConnectionFromSecrets(_awsCredData[0], _awsCredData[1], _awsCredData[2]);
			}
			
			if (args[0].equals("S3_LIST_BUCKETS")) {
				List<Bucket> buckets_ = getS3().listBuckets();

				ObjectMapper mapper_ = new ObjectMapper();
				System.out.println(mapper_.writerWithDefaultPrettyPrinter().writeValueAsString(buckets_));
			} else if (args[0].equals("S3_PUT_OBJ")) {
				PutObjectRequest por_ = null;

				if (args[1].equals("-")) {
					ObjectMetadata objectMetadata_ = new ObjectMetadata();
					por_ = new PutObjectRequest(bucketName_, bucketObjKey_, System.in, objectMetadata_);
				} else {
					por_ = new PutObjectRequest(bucketName_, bucketObjKey_, new File(args[1]));
				}

				if (keyARN_ != null) {
					por_ = por_.withSSEAwsKeyManagementParams(new SSEAwsKeyManagementParams(keyARN_));
				}

				getS3().putObject(por_);
			} else if (args[0].equals("S3_GET_OBJ")) {
				noClobber(args[2]);

				GetObjectRequest gor_ = new GetObjectRequest(bucketName_, bucketObjKey_);
				S3Object s3Obj_ = getS3().getObject(gor_);

				is_ = s3Obj_.getObjectContent();

				_logger.info(String.format("Content-Type='%s'", s3Obj_.getObjectMetadata().getContentType()));

				if (args[2].equals("-")) {
					byte[] buf_ = new byte[8 * 1024];
					int cnt_;

					while ((cnt_ = is_.read(buf_)) != -1) {
						if (Thread.interrupted()) {
							throw new InterruptedException();
						}
						System.out.write(buf_, 0, cnt_);
					}
				} else {
					Files.copy(is_, Paths.get(args[2]));
				}
			} else if (args[0].equals("S3_LIST_BUCKET")) {
				ListObjectsV2Request lor_ = new ListObjectsV2Request().withBucketName(bucketName_);
				ListObjectsV2Result result_;

				if (listBucketPrefix_ != null) {
					lor_ = lor_.withPrefix(listBucketPrefix_);
				}

				if (listBucketDelimiter_ != null) {
					lor_ = lor_.withDelimiter(listBucketDelimiter_);
				}
				
				if (listBucketMaxKeys_ > 0) {
					lor_ = lor_.withMaxKeys(listBucketMaxKeys_);
				}

				do {
					result_ = getS3().listObjectsV2(lor_);

					System.out.println(new ObjectMapper().writerWithDefaultPrettyPrinter().writeValueAsString(result_));
					// If there are more than maxKeys keys in the bucket, get a
					// continuation token
					// and list the next objects.
					String token_ = result_.getNextContinuationToken();
					// System.out.println("Next Continuation Token: " + token);
					lor_.setContinuationToken(token_);
				} while (result_.isTruncated());
			} else if (args[0].equals("LAMBDA")) {
				noClobber(args[3]);

				String s_ = slurpFile(args[2]);
				InvokeRequest req_ = new InvokeRequest().withFunctionName(args[1]).withPayload(s_);
				InvokeResult result_ = getLambda().invoke(req_);
				ByteBuffer byteBuf_ = result_.getPayload();

				if (byteBuf_ != null) {
					if (args[3].equals("-")) {
						System.out.println(Charset.defaultCharset().decode(byteBuf_).toString());
					} else {
						FileOutputStream out_ = new FileOutputStream(args[3]);
						out_.getChannel().write(byteBuf_);
						out_.close();
					}
				} else {
					_logger.info("LAMBDA result payload is null");
				}
			} else if (args[0].indexOf("QUERY") > -1) {
				noClobber(args[2]);
				
				final AtomicBoolean isResultComplete_ = new AtomicBoolean(false);
				String query_ = slurpFile(args[3]);
				SelectObjectContentRequest socr_ = generateBaseRequest(args[0], bucketName_, bucketObjKey_, query_);
				try (
						OutputStream os_ = args[2].equals("-") ? System.out : new FileOutputStream(new File(args[2]));
						SelectObjectContentResult result_ = getS3().selectObjectContent(socr_)) {
							InputStream ris_ = result_.getPayload()
							.getRecordsInputStream(new SelectObjectContentEventVisitor() {
									@Override
									public void visit(SelectObjectContentEvent.StatsEvent event_) {
										_logger.info(
												"Received Stats, Bytes Scanned: " + event_.getDetails().getBytesScanned()
														+ " Bytes Processed: " + event_.getDetails().getBytesProcessed());
									}
	
									/*
									 * An End Event informs that the request has
									 * finished successfully.
									 */
									@Override
									public void visit(SelectObjectContentEvent.EndEvent event_) {
										isResultComplete_.set(true);
										_logger.info("Received End Event. Result is complete.");
									}
								}
							);

					copy(ris_, os_);
				}
				if (!isResultComplete_.get()) {
					throw new Exception("S3 Select request was incomplete as End Event was not received.");
				}
			}

			exitCode_ = 0;
			_logger.info(String.format("SUCCESSFUL %s", args[0]));
		} catch (AmazonServiceException e_) {
			// The call was transmitted successfully, but Amazon S3 couldn't
			// process
			// it, so it returned an error response.
			_logger.fatal("EXITING", e_);
		} catch (SdkClientException e_) {
			// Amazon S3 couldn't be contacted for a response, or the client
			// couldn't parse the response from Amazon S3.
			_logger.fatal("EXITING", e_);
		} catch (Exception e_) {
			_logger.fatal("EXITING", e_);
		} finally {
			if (is_ != null) {
				try {
					is_.close();
				} catch (Exception e_) {
				}
			}
		}

		System.exit(exitCode_);
	}

	private static AWSLambda getLambda() {
		AWSLambdaClientBuilder builder_ = AWSLambdaClientBuilder.standard()
			.withCredentials(new AWSStaticCredentialsProvider(_sessionCredentials))
			.withClientConfiguration(_clientConf);

		if (_regionFromEnv == null) {
			builder_ = builder_.withRegion(_defaultRegion);
		}

		return builder_.build();
	}

	private static AmazonS3 getS3() {
		AmazonS3ClientBuilder builder_ = AmazonS3ClientBuilder.standard()
				.withCredentials(new AWSStaticCredentialsProvider(_sessionCredentials))
				.withClientConfiguration(_clientConf);

		if (_regionFromEnv == null) {
			builder_ = builder_.withRegion(_defaultRegion);
		}

		return builder_.build();
	}
	
	private static void noClobber(String path) throws Exception {
		if (path.equals("-")) {
			return;
		}
		
		if (Paths.get(path).toFile().exists()) {
			throw new Exception("FILE EXISTS " + path);
		}
	}
	private static String slurpFile(String path) throws Exception {
		byte[] buf_ = path.equals("-") ? toByteArray(System.in) : Files.readAllBytes(Paths.get(path));
		return new String(buf_, Charset.defaultCharset());
	}

	private static void initSSL() throws Exception {
		if (_clientConf == null) {
			InputStream propInputStream_ = Driver.class.getClassLoader()
					.getResourceAsStream("saml.properties");
			Properties config_ = new Properties();

			config_.load(propInputStream_);

			String trustStoreAPassword_ = new String(
					org.apache.commons.codec.binary.Base64.decodeBase64(config_.getProperty("TRUST_STORE_PASSWORD")));

			KeyStore trustKeyStore_ = KeyStore.getInstance("JKS");
			trustKeyStore_.load(
					Driver.class.getClassLoader().getResourceAsStream(config_.getProperty("TRUST_STORE")),
					trustStoreAPassword_.toCharArray());

			SSLContext sslcontext_ = SSLContexts.custom()
					.loadTrustMaterial(trustKeyStore_, new TrustSelfSignedStrategy()).build();
			SSLConnectionSocketFactory sslsf_ = new SSLConnectionSocketFactory(sslcontext_, new String[] { "TLSv1.2" },
					null, SSLConnectionSocketFactory.getDefaultHostnameVerifier());

			_clientConf = new ClientConfiguration();

			_clientConf.getApacheHttpClientConfig().setSslSocketFactory(sslsf_);

			_clientConf.setProtocol(Protocol.HTTPS);
            _clientConf.setProxyHost(config_.getProperty("PROXY_HOST"));
            _clientConf.setProxyPort(Integer.parseInt(config_.getProperty("PROXY_PORT")));
		}
	}

	private static void initConnectionFromSecrets(String awsAccessKey, String awsSecretKey, String sessionToken) throws Exception {
		if (_sessionCredentials == null) {
			_sessionCredentials = new BasicSessionCredentials(awsAccessKey, awsSecretKey, sessionToken);
			_logger.info(String.format("AWSCredentialAccessKeyId=%s", _sessionCredentials.getAWSAccessKeyId()));
			_logger.info(String.format("AWSCredentialSecretAccessKey=%s", _sessionCredentials.getAWSSecretKey()));
			_logger.info(String.format("AWSCredentialSessionToken=%s", _sessionCredentials.getSessionToken()));
		}
		initSSL();
	}
    private static void initConnectionFromFederation(String userName, String password, String role) throws Exception {
        if (_sessionCredentials == null) {
                AWSFederationAccess fed_ = new AWSFederationAccess();
                _sessionCredentials = fed_.getBasicSessionCredentials(userName, password, role);

                _logger.info(String.format("AWSCredentialAccessKeyId=%s", _sessionCredentials.getAWSAccessKeyId()));
                _logger.info(String.format("AWSCredentialSecretAccessKey=%s", _sessionCredentials.getAWSSecretKey()));
                _logger.info(String.format("AWSCredentialSessionToken=%s", _sessionCredentials.getSessionToken()));
        }
        initSSL();
    }

	private static SelectObjectContentRequest generateBaseRequest(String format, String bucket, String key, String query) {
		SelectObjectContentRequest req_ = new SelectObjectContentRequest();

		req_.setBucketName(bucket);
		req_.setKey(key);
		req_.setExpression(query);

		req_.setExpressionType(ExpressionType.SQL);

		InputSerialization is_ = new InputSerialization();

		if (format.indexOf("CSV") < 0) {
			if (format.indexOf("DOCUMENT") > -1) {
				is_.setJson(new JSONInput().withType(JSONType.DOCUMENT));
			}
			else {
				is_.setJson(new JSONInput().withType(JSONType.LINES));
			}
		}
		else {
			is_.setCsv(new CSVInput());
		}
		if (format.indexOf("GZIP") > -1) {
			is_.setCompressionType(CompressionType.GZIP);
		}
		else {
			is_.setCompressionType(CompressionType.NONE);
		}

		req_.setInputSerialization(is_);

		OutputSerialization os_ = new OutputSerialization();
		if (format.indexOf("CSV") < 0) {
			os_.setJson(new JSONOutput());
		}
		else {
			os_.setCsv(new CSVOutput());
		}
		req_.setOutputSerialization(os_);

		return req_;
	}
}
