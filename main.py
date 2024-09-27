import os
import boto3
import random
import base64
from botocore.config import Config


def lambda_handler(event, context):
    try:
        if event["requestContext"]["http"]["method"] == "GET":
            return get_random_photo_html()
        elif event["requestContext"]["http"]["method"] == "POST":
            return handle_upload(event)
    except Exception as e:
        return error_response(f"Unexpected error: {str(e)}")


def get_random_photo_html():
    try:
        image_url = get_random_image_s3()
        with open("index.html", "r") as file:
            html_template = file.read()
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "text/html"},
            "body": html_template.replace("{image_url}", image_url),
        }
    except Exception as e:
        return error_response(f"Error getting random photo: {str(e)}")


def handle_upload(event):
    try:
        content_type = event["headers"].get("content-type", "")
        if "multipart/form-data" in content_type:
            body = (
                base64.b64decode(event["body"])
                if event.get("isBase64Encoded", False)
                else event["body"].encode("utf-8")
            )
            boundary = content_type.split("=")[1].encode()
            parts = body.split(boundary)
            for part in parts:
                if b"filename" in part:
                    image_data = part.split(b"\r\n\r\n")[1].rstrip(b"\r\n--")
                    return upload_photo(image_data)
        return error_response("No file was uploaded", 400)
    except Exception as e:
        return error_response(f"Error handling upload: {str(e)}")


def upload_photo(photo_file):
    bucket = os.environ["IMAGES_BUCKET"]
    s3 = boto3.client("s3", config=Config(signature_version="s3v4"))

    if not is_valid_image(photo_file):
        return error_response("Uploaded file is not a valid image", 400)

    try:
        filename = f"{random.randint(1000000, 9999999)}.jpg"
        s3.put_object(Bucket=bucket, Key=filename, Body=photo_file)
        return {"statusCode": 200, "body": "Photo uploaded successfully"}
    except Exception as e:
        return error_response(f"Error uploading photo: {str(e)}")


def get_random_image_s3():
    bucket = os.environ["IMAGES_BUCKET"]
    s3 = boto3.client("s3", config=Config(signature_version="s3v4"))

    try:
        response = s3.list_objects_v2(Bucket=bucket)
        image_keys = [
            obj["Key"]
            for obj in response.get("Contents", [])
            if obj["Key"].lower().endswith((".jpg", ".jpeg", ".png"))
        ]

        if not image_keys:
            return "https://images.unsplash.com/photo-1605054576990-8d1d1e623fad?q=80&w=2340&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"

        random_image_key = random.choice(image_keys)
        return s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": bucket, "Key": random_image_key},
            ExpiresIn=300,
        )
    except Exception as e:
        raise Exception(f"Error retrieving random image: {str(e)}")


def is_valid_image(file_data):
    return file_data.startswith(b"\xff\xd8") or file_data.startswith(b"\x89PNG")


def error_response(message, status_code=500):
    return {"statusCode": status_code, "body": f"Error: {message}"}