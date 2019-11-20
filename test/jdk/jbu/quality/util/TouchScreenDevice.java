package quality.util;

import javax.swing.*;
import java.awt.*;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.io.IOException;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public class TouchScreenDevice implements AutoCloseable {
    // todo add product id
    private int width;
    private int height;
    private int fileDescriptor;

    static {
        System.loadLibrary("touchscreen_device");
    }

    public TouchScreenDevice(int width, int height) throws IOException {
        this.width = width;
        this.height = height;
        fileDescriptor = create(getWidth(), getHeight());
        checkCompletion(fileDescriptor,
                "Failed to create virtual touchscreen device");
    }

    @Override
    public void close() throws Exception {
        checkCompletion(destroy(fileDescriptor),
                "");
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public void click(int trackingId, int x, int y) throws IOException {
        checkCompletion(clickImpl(fileDescriptor, trackingId, x, y),
                "Failed to click on touchscreen device");

    }

    public void move(int trackingId, int fromX, int fromY, int toX, int toY) throws IOException {
        checkCompletion(moveImpl(fileDescriptor, trackingId, fromX, fromY, toX, toY),
                "Failed to move on virtual touchscreen device");

    }

    private void checkCompletion(int code, String errorMessage) throws IOException {
        if (code < 0) {
            throw new IOException(errorMessage);
        }
    }

    private native int create(int width, int height);

    private native int destroy(int fd);

    private native int clickImpl(int fd, int trackingId, int x, int y);

    private native int moveImpl(int fd, int trackingId, int fromX, int fromY, int toX, int toY);
}


