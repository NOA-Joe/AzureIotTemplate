//
//  ViewController.m
//  AzureIotTemplate
//
//  Created by NOA-Labs on 2019/10/31.
//  Copyright © 2019 NOA-Labs. All rights reserved.
//

#import "ViewController.h"

#include "iothub.h"
#include "iothub_device_client_ll.h"
#include "iothub_client_options.h"
#include "iothub_message.h"
#include "azure_c_shared_utility/threadapi.h"
#include "azure_c_shared_utility/shared_util_options.h"

/* This sample uses the _LL APIs of iothub_client for example purposes.
Simply changing the using the convenience layer (functions not having _LL)
and removing calls to _DoWork will yield the same results. */

// The protocol you wish to use should be uncommented
//
#define SAMPLE_MQTT
//#define SAMPLE_MQTT_OVER_WEBSOCKETS
//#define SAMPLE_AMQP
//#define SAMPLE_AMQP_OVER_WEBSOCKETS
//#define SAMPLE_HTTP

#ifdef SAMPLE_MQTT
    #include "iothubtransportmqtt.h"
#endif // SAMPLE_MQTT
#ifdef SAMPLE_MQTT_OVER_WEBSOCKETS
    #include "iothubtransportmqtt_websockets.h"
#endif // SAMPLE_MQTT_OVER_WEBSOCKETS
#ifdef SAMPLE_AMQP
    #include "iothubtransportamqp.h"
#endif // SAMPLE_AMQP
#ifdef SAMPLE_AMQP_OVER_WEBSOCKETS
    #include "iothubtransportamqp_websockets.h"
#endif // SAMPLE_AMQP_OVER_WEBSOCKETS
#ifdef SAMPLE_HTTP
    #include "iothubtransporthttp.h"
#endif // SAMPLE_HTTP

#ifdef MBED_BUILD_TIMESTAMP
    #define SET_TRUSTED_CERT_IN_SAMPLES
#endif // MBED_BUILD_TIMESTAMP

#define SET_TRUSTED_CERT_IN_SAMPLES 1   //set to 1 to use trused cert, set to 0 to use x509 cert

#ifdef SET_TRUSTED_CERT_IN_SAMPLES
    #include "certs.h"
#endif // SET_TRUSTED_CERT_IN_SAMPLES

/* Paste in the your x509 iothub connection string  */
/*  "HostName=<host_name>;DeviceId=<device_id>;x509=true"                      */
static const char* connectionString = "YOUR CONNECTION STRING";

static const char* x509certificate =
"-----BEGIN CERTIFICATE-----""\n"
"...""\n"
"-----END CERTIFICATE-----";

static const char* x509privatekey =
"-----BEGIN RSA PRIVATE KEY-----""\n"
"...""\n"
"-----END RSA PRIVATE KEY-----";

#define MESSAGE_COUNT        5
static bool g_continueRunning = true;
static size_t g_message_count_send_confirmations = 0;

typedef struct EVENT_INSTANCE_TAG
{
    IOTHUB_MESSAGE_HANDLE messageHandle;
    size_t messageTrackingId;  // For tracking the messages within the user callback.
} EVENT_INSTANCE;

static void send_confirm_callback(IOTHUB_CLIENT_CONFIRMATION_RESULT result, void* userContextCallback)
{
    (void)userContextCallback;
    // When a message is sent this callback will get envoked
    g_message_count_send_confirmations++;
    (void)printf("Confirmation callback received for message %zu with result %s\r\n", g_message_count_send_confirmations, MU_ENUM_TO_STRING(IOTHUB_CLIENT_CONFIRMATION_RESULT, result));
}

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    

        IOTHUB_CLIENT_TRANSPORT_PROVIDER protocol;
        IOTHUB_MESSAGE_HANDLE message_handle;
        size_t messages_sent = 0;
        const char* telemetry_msg = "test_message";

        // Select the Protocol to use with the connection
    #ifdef SAMPLE_MQTT
        protocol = MQTT_Protocol;
    #endif // SAMPLE_MQTT
    #ifdef SAMPLE_MQTT_OVER_WEBSOCKETS
        protocol = MQTT_WebSocket_Protocol;
    #endif // SAMPLE_MQTT_OVER_WEBSOCKETS
    #ifdef SAMPLE_AMQP
        protocol = AMQP_Protocol;
    #endif // SAMPLE_AMQP
    #ifdef SAMPLE_AMQP_OVER_WEBSOCKETS
        protocol = AMQP_Protocol_over_WebSocketsTls;
    #endif // SAMPLE_AMQP_OVER_WEBSOCKETS
    #ifdef SAMPLE_HTTP
        protocol = HTTP_Protocol;
    #endif // SAMPLE_HTTP

        IOTHUB_DEVICE_CLIENT_LL_HANDLE device_ll_handle;

        // Used to initialize IoTHub SDK subsystem
        (void)IoTHub_Init();

        (void)printf("Creating IoTHub handle\r\n");
        // Create the iothub handle here
        device_ll_handle = IoTHubDeviceClient_LL_CreateFromConnectionString(connectionString, protocol);
        if (device_ll_handle == NULL)
        {
            (void)printf("Failure createing Iothub device.  Hint: Check you connection string.\r\n");
        }
        else
        {
            // Set any option that are neccessary.
            // For available options please see the iothub_sdk_options.md documentation
            bool traceOn = true;
            IoTHubDeviceClient_LL_SetOption(device_ll_handle, OPTION_LOG_TRACE, &traceOn);

            // Setting the Trusted Certificate.  This is only necessary on system with without
            // built in certificate stores.
    #ifdef SET_TRUSTED_CERT_IN_SAMPLES
            IoTHubDeviceClient_LL_SetOption(device_ll_handle, OPTION_TRUSTED_CERT, certificates);
    #endif // SET_TRUSTED_CERT_IN_SAMPLES

            // Set the X509 certificates in the SDK
            if (
                (IoTHubDeviceClient_LL_SetOption(device_ll_handle, OPTION_X509_CERT, x509certificate) != IOTHUB_CLIENT_OK) ||
                (IoTHubDeviceClient_LL_SetOption(device_ll_handle, OPTION_X509_PRIVATE_KEY, x509privatekey) != IOTHUB_CLIENT_OK)
                )
            {
                printf("failure to set options for x509, aborting\r\n");
            }
            else
            {
                do
                {
                    if (messages_sent < MESSAGE_COUNT)
                    {
                        // Construct the iothub message from a string or a byte array
                        message_handle = IoTHubMessage_CreateFromString(telemetry_msg);
                        //message_handle = IoTHubMessage_CreateFromByteArray((const unsigned char*)msgText, strlen(msgText)));

                        // Set Message property
                        (void)IoTHubMessage_SetMessageId(message_handle, "MSG_ID");
                        (void)IoTHubMessage_SetCorrelationId(message_handle, "CORE_ID");
                        (void)IoTHubMessage_SetContentTypeSystemProperty(message_handle, "application%2Fjson");
                        (void)IoTHubMessage_SetContentEncodingSystemProperty(message_handle, "utf-8");

                        // Add custom properties to message
                        (void)IoTHubMessage_SetProperty(message_handle, "property_key", "property_value");

                        (void)printf("Sending message %d to IoTHub\r\n", (int)(messages_sent + 1));
                        IoTHubDeviceClient_LL_SendEventAsync(device_ll_handle, message_handle, send_confirm_callback, NULL);

                        // The message is copied to the sdk so the we can destroy it
                        IoTHubMessage_Destroy(message_handle);

                        messages_sent++;
                    }
                    else if (g_message_count_send_confirmations >= MESSAGE_COUNT)
                    {
                        // After all messages are all received stop running
                        g_continueRunning = false;
                    }

                    IoTHubDeviceClient_LL_DoWork(device_ll_handle);
                    ThreadAPI_Sleep(100);

                } while (g_continueRunning);
            }
            // Clean up the iothub sdk handle
            IoTHubDeviceClient_LL_Destroy(device_ll_handle);
        }
        // Free all the sdk subsystem
        IoTHub_Deinit();

        printf("Press any key to continue");
        (void)getchar();
}


@end
