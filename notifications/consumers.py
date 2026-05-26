import json

from channels.generic.websocket import (
    AsyncWebsocketConsumer
)


class NotificationConsumer(
    AsyncWebsocketConsumer
):

    async def connect(self):

        self.room_group_name = (
            "notifications"
        )

        # JOIN GROUP
        await self.channel_layer.group_add(

            self.room_group_name,

            self.channel_name
        )

        await self.accept()

        print(
            "WebSocket Connected"
        )

    async def disconnect(
        self,
        close_code
    ):

        # LEAVE GROUP
        await self.channel_layer.group_discard(

            self.room_group_name,

            self.channel_name
        )

        print(
            "WebSocket Disconnected"
        )

    # ==========================
    # RECEIVE MESSAGE
    # ==========================
    async def receive(
        self,
        text_data
    ):

        data = json.loads(
            text_data
        )

        message = data.get(
            "message"
        )

        # SEND TO GROUP
        await self.channel_layer.group_send(

            self.room_group_name,

            {

                "type":
                "send_notification",

                "message":
                message
            }
        )

    # ==========================
    # SEND TO FRONTEND
    # ==========================
    async def send_notification(
        self,
        event
    ):

        await self.send(

            text_data=json.dumps({

                "message":
                event["message"]
            })
        )