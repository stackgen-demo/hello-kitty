import os
import boto3
import random
from botocore.config import Config


def lambda_handler(event, context):
    image_number = random.randint(1, 6) # 6 images in the bucket

    try:
        image_url, attribution_text = get_image_s3(image_number)
    except Exception as e:
        return {"statusCode": 500, "body": f"Error: {str(e)}"}

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html"},
        "body": f"""
            <html>
            <head>
                <title>Random Cat Photo</title>
                <link
                rel="stylesheet"
                href="https://cdn.jsdelivr.net/npm/water.css@2/out/water.css"
                />
            </head>
            <body
                style="
                height: 100vh;
                margin: 0;
                display: flex;
                justify-content: center;
                align-items: center;
                max-width: 100vw;
                "
            >
                <div
                style="
                    display: flex;
                    flex-direction: column;
                    gap: 8px;
                    align-items: center;
                "
                >
                <img style="height: 500px" src="{image_url}" />
                <p>{attribution_text}</p>
                </div>
            </body>
            </html>
        """,
    }


def get_image_s3(image_number):
    bucket = os.environ["IMAGES_BUCKET"]
    config = Config(signature_version='s3v4')
    s3 = boto3.client("s3",config=config)

    image_key = f"{image_number}.jpg"
    attribution_text_key = f"{image_number}.txt"

    image_url = s3.generate_presigned_url(
        "get_object", Params={"Bucket": bucket, "Key": image_key}, ExpiresIn=300
    )

    print(f"Image URL: {image_url}")

    attribution_text = s3.get_object(Bucket=bucket, Key=attribution_text_key)
    attribution_text = attribution_text["Body"].read().decode("utf-8")

    return image_url, attribution_text
