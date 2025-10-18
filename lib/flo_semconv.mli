(** OpenTelemetry Semantic Conventions

    This module provides helpers for OpenTelemetry semantic conventions,
    which define standard attribute names for common operations and data.

    All functions return (string * Value.t) tuples that can be used
    directly with structured logging functions.

    See: https://opentelemetry.io/docs/specs/semconv/
*)

(** {1 General Attributes} *)

(** Service name identifying the application.
    @param name The service name
    @return ("service.name", Value.String name)
*)
val service_name : string -> string * Value.t

(** Service version.
    @param version The service version
    @return ("service.version", Value.String version)
*)
val service_version : string -> string * Value.t

(** Service instance ID.
    @param id The instance identifier
    @return ("service.instance.id", Value.String id)
*)
val service_instance_id : string -> string * Value.t

(** Deployment environment (e.g., "production", "staging", "development").
    @param env The environment name
    @return ("deployment.environment", Value.String env)
*)
val deployment_environment : string -> string * Value.t

(** {1 HTTP Attributes} *)

(** HTTP request method.
    @param method_ HTTP method (e.g., "GET", "POST")
    @return ("http.method", Value.String method_)
*)
val http_method : string -> string * Value.t

(** HTTP response status code.
    @param status HTTP status code (e.g., 200, 404)
    @return ("http.status_code", Value.Int status)
*)
val http_status_code : int -> string * Value.t

(** Full HTTP request URL.
    @param url The request URL
    @return ("http.url", Value.String url)
*)
val http_url : string -> string * Value.t

(** HTTP request target (path and query string).
    @param target Request target (e.g., "/api/users?id=123")
    @return ("http.target", Value.String target)
*)
val http_target : string -> string * Value.t

(** HTTP host header value.
    @param host The host value
    @return ("http.host", Value.String host)
*)
val http_host : string -> string * Value.t

(** HTTP scheme (http or https).
    @param scheme The scheme
    @return ("http.scheme", Value.String scheme)
*)
val http_scheme : string -> string * Value.t

(** HTTP user agent header.
    @param user_agent The user agent string
    @return ("http.user_agent", Value.String user_agent)
*)
val http_user_agent : string -> string * Value.t

(** HTTP request content length.
    @param length Content length in bytes
    @return ("http.request.body.size", Value.Int length)
*)
val http_request_body_size : int -> string * Value.t

(** HTTP response content length.
    @param length Content length in bytes
    @return ("http.response.body.size", Value.Int length)
*)
val http_response_body_size : int -> string * Value.t

(** HTTP route pattern.
    @param route The route pattern (e.g., "/users/:id")
    @return ("http.route", Value.String route)
*)
val http_route : string -> string * Value.t

(** {1 Database Attributes} *)

(** Database system identifier.
    @param system Database system (e.g., "postgresql", "mysql", "mongodb")
    @return ("db.system", Value.String system)
*)
val db_system : string -> string * Value.t

(** Database name.
    @param name The database name
    @return ("db.name", Value.String name)
*)
val db_name : string -> string * Value.t

(** Database operation name.
    @param operation Operation type (e.g., "SELECT", "INSERT", "find")
    @return ("db.operation", Value.String operation)
*)
val db_operation : string -> string * Value.t

(** Database statement or query.
    @param statement The SQL statement or query
    @return ("db.statement", Value.String statement)
*)
val db_statement : string -> string * Value.t

(** Database user name.
    @param user The database user
    @return ("db.user", Value.String user)
*)
val db_user : string -> string * Value.t

(** Database connection string.
    @param connection_string The connection string (sanitized)
    @return ("db.connection_string", Value.String connection_string)
*)
val db_connection_string : string -> string * Value.t

(** Name of the table being accessed.
    @param table The table name
    @return ("db.sql.table", Value.String table)
*)
val db_sql_table : string -> string * Value.t

(** {1 Messaging Attributes} *)

(** Messaging system identifier.
    @param system Messaging system (e.g., "kafka", "rabbitmq", "sqs")
    @return ("messaging.system", Value.String system)
*)
val messaging_system : string -> string * Value.t

(** Message destination name.
    @param destination Destination name (e.g., topic, queue)
    @return ("messaging.destination", Value.String destination)
*)
val messaging_destination : string -> string * Value.t

(** Kind of message destination.
    @param kind Destination kind ("queue" or "topic")
    @return ("messaging.destination.kind", Value.String kind)
*)
val messaging_destination_kind : string -> string * Value.t

(** Message identifier.
    @param id Message ID
    @return ("messaging.message.id", Value.String id)
*)
val messaging_message_id : string -> string * Value.t

(** Messaging protocol name.
    @param protocol Protocol name (e.g., "AMQP", "MQTT")
    @return ("messaging.protocol", Value.String protocol)
*)
val messaging_protocol : string -> string * Value.t

(** Message payload size in bytes.
    @param size Payload size
    @return ("messaging.message.payload_size_bytes", Value.Int size)
*)
val messaging_message_payload_size : int -> string * Value.t

(** {1 RPC Attributes} *)

(** RPC system identifier.
    @param system RPC system (e.g., "grpc", "java_rmi")
    @return ("rpc.system", Value.String system)
*)
val rpc_system : string -> string * Value.t

(** RPC service name.
    @param service Service name
    @return ("rpc.service", Value.String service)
*)
val rpc_service : string -> string * Value.t

(** RPC method name.
    @param method_ Method name
    @return ("rpc.method", Value.String method_)
*)
val rpc_method : string -> string * Value.t

(** {1 Error Attributes} *)

(** Error type or class.
    @param type_ Error type (e.g., exception class name)
    @return ("error.type", Value.String type_)
*)
val error_type : string -> string * Value.t

(** Error message.
    @param message Error message
    @return ("error.message", Value.String message)
*)
val error_message : string -> string * Value.t

(** Error stack trace.
    @param stack_trace Stack trace as string
    @return ("error.stack_trace", Value.String stack_trace)
*)
val error_stack_trace : string -> string * Value.t

(** {1 Network Attributes} *)

(** Network protocol name.
    @param protocol Protocol (e.g., "tcp", "udp")
    @return ("net.protocol.name", Value.String protocol)
*)
val net_protocol_name : string -> string * Value.t

(** Network protocol version.
    @param version Protocol version (e.g., "1.1", "2.0")
    @return ("net.protocol.version", Value.String version)
*)
val net_protocol_version : string -> string * Value.t

(** Peer address (IP or hostname).
    @param address Peer address
    @return ("net.peer.name", Value.String address)
*)
val net_peer_name : string -> string * Value.t

(** Peer port number.
    @param port Port number
    @return ("net.peer.port", Value.Int port)
*)
val net_peer_port : int -> string * Value.t

(** {1 User Attributes} *)

(** User identifier.
    @param id User ID
    @return ("user.id", Value.String id)
*)
val user_id : string -> string * Value.t

(** User email address.
    @param email Email address
    @return ("user.email", Value.String email)
*)
val user_email : string -> string * Value.t

(** User name.
    @param name User name
    @return ("user.name", Value.String name)
*)
val user_name : string -> string * Value.t

(** User roles.
    @param roles List of user roles
    @return ("user.roles", Value.Array [...])
*)
val user_roles : string list -> string * Value.t

(** {1 Cloud Attributes} *)

(** Cloud provider identifier.
    @param provider Provider (e.g., "aws", "gcp", "azure")
    @return ("cloud.provider", Value.String provider)
*)
val cloud_provider : string -> string * Value.t

(** Cloud account ID.
    @param account_id Account identifier
    @return ("cloud.account.id", Value.String account_id)
*)
val cloud_account_id : string -> string * Value.t

(** Cloud region.
    @param region Region (e.g., "us-east-1")
    @return ("cloud.region", Value.String region)
*)
val cloud_region : string -> string * Value.t

(** Cloud availability zone.
    @param zone Availability zone
    @return ("cloud.availability_zone", Value.String zone)
*)
val cloud_availability_zone : string -> string * Value.t

(** {1 Host Attributes} *)

(** Host name.
    @param name Hostname
    @return ("host.name", Value.String name)
*)
val host_name : string -> string * Value.t

(** Host type.
    @param type_ Host type (e.g., "t2.micro")
    @return ("host.type", Value.String type_)
*)
val host_type : string -> string * Value.t

(** Host architecture.
    @param arch Architecture (e.g., "x86_64", "arm64")
    @return ("host.arch", Value.String arch)
*)
val host_arch : string -> string * Value.t

(** {1 Process Attributes} *)

(** Process ID.
    @param pid Process identifier
    @return ("process.pid", Value.Int pid)
*)
val process_pid : int -> string * Value.t

(** Process executable name.
    @param name Executable name
    @return ("process.executable.name", Value.String name)
*)
val process_executable_name : string -> string * Value.t

(** Process command line.
    @param command_line Full command line
    @return ("process.command_line", Value.String command_line)
*)
val process_command_line : string -> string * Value.t

(** {1 Performance Attributes} *)

(** Duration in milliseconds.
    @param ms Duration in milliseconds
    @return ("duration_ms", Value.Float ms)
*)
val duration_ms : float -> string * Value.t

(** Duration in seconds.
    @param seconds Duration in seconds
    @return ("duration", Value.Float seconds)
*)
val duration : float -> string * Value.t

(** {1 Session Attributes} *)

(** Session ID.
    @param id Session identifier
    @return ("session.id", Value.String id)
*)
val session_id : string -> string * Value.t

(** Request ID.
    @param id Request identifier
    @return ("request.id", Value.String id)
*)
val request_id : string -> string * Value.t

(** Correlation ID for distributed tracing.
    @param id Correlation identifier
    @return ("correlation.id", Value.String id)
*)
val correlation_id : string -> string * Value.t
