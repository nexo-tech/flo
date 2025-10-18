(** OpenTelemetry Semantic Conventions implementation *)

(** {1 General Attributes} *)

let service_name name = ("service.name", Value.String name)
let service_version version = ("service.version", Value.String version)
let service_instance_id id = ("service.instance.id", Value.String id)
let deployment_environment env = ("deployment.environment", Value.String env)

(** {1 HTTP Attributes} *)

let http_method method_ = ("http.method", Value.String method_)
let http_status_code status = ("http.status_code", Value.Int (Int64.of_int status))
let http_url url = ("http.url", Value.String url)
let http_target target = ("http.target", Value.String target)
let http_host host = ("http.host", Value.String host)
let http_scheme scheme = ("http.scheme", Value.String scheme)
let http_user_agent user_agent = ("http.user_agent", Value.String user_agent)
let http_request_body_size length = ("http.request.body.size", Value.Int (Int64.of_int length))
let http_response_body_size length = ("http.response.body.size", Value.Int (Int64.of_int length))
let http_route route = ("http.route", Value.String route)

(** {1 Database Attributes} *)

let db_system system = ("db.system", Value.String system)
let db_name name = ("db.name", Value.String name)
let db_operation operation = ("db.operation", Value.String operation)
let db_statement statement = ("db.statement", Value.String statement)
let db_user user = ("db.user", Value.String user)
let db_connection_string connection_string = ("db.connection_string", Value.String connection_string)
let db_sql_table table = ("db.sql.table", Value.String table)

(** {1 Messaging Attributes} *)

let messaging_system system = ("messaging.system", Value.String system)
let messaging_destination destination = ("messaging.destination", Value.String destination)
let messaging_destination_kind kind = ("messaging.destination.kind", Value.String kind)
let messaging_message_id id = ("messaging.message.id", Value.String id)
let messaging_protocol protocol = ("messaging.protocol", Value.String protocol)
let messaging_message_payload_size size =
  ("messaging.message.payload_size_bytes", Value.Int (Int64.of_int size))

(** {1 RPC Attributes} *)

let rpc_system system = ("rpc.system", Value.String system)
let rpc_service service = ("rpc.service", Value.String service)
let rpc_method method_ = ("rpc.method", Value.String method_)

(** {1 Error Attributes} *)

let error_type type_ = ("error.type", Value.String type_)
let error_message message = ("error.message", Value.String message)
let error_stack_trace stack_trace = ("error.stack_trace", Value.String stack_trace)

(** {1 Network Attributes} *)

let net_protocol_name protocol = ("net.protocol.name", Value.String protocol)
let net_protocol_version version = ("net.protocol.version", Value.String version)
let net_peer_name address = ("net.peer.name", Value.String address)
let net_peer_port port = ("net.peer.port", Value.Int (Int64.of_int port))

(** {1 User Attributes} *)

let user_id id = ("user.id", Value.String id)
let user_email email = ("user.email", Value.String email)
let user_name name = ("user.name", Value.String name)
let user_roles roles =
  let role_values = List.map (fun r -> Value.String r) roles in
  ("user.roles", Value.Array role_values)

(** {1 Cloud Attributes} *)

let cloud_provider provider = ("cloud.provider", Value.String provider)
let cloud_account_id account_id = ("cloud.account.id", Value.String account_id)
let cloud_region region = ("cloud.region", Value.String region)
let cloud_availability_zone zone = ("cloud.availability_zone", Value.String zone)

(** {1 Host Attributes} *)

let host_name name = ("host.name", Value.String name)
let host_type type_ = ("host.type", Value.String type_)
let host_arch arch = ("host.arch", Value.String arch)

(** {1 Process Attributes} *)

let process_pid pid = ("process.pid", Value.Int (Int64.of_int pid))
let process_executable_name name = ("process.executable.name", Value.String name)
let process_command_line command_line = ("process.command_line", Value.String command_line)

(** {1 Performance Attributes} *)

let duration_ms ms = ("duration_ms", Value.Float ms)
let duration seconds = ("duration", Value.Float seconds)

(** {1 Session Attributes} *)

let session_id id = ("session.id", Value.String id)
let request_id id = ("request.id", Value.String id)
let correlation_id id = ("correlation.id", Value.String id)
