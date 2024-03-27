package com.github.shadowsocks.plugin.hnzgost;

import android.net.Uri;
import android.os.Debug;
import android.os.ParcelFileDescriptor;
import com.github.shadowsocks.plugin.NativePluginProvider;
import com.github.shadowsocks.plugin.PathProvider;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.Console;
import java.io.File;
import java.io.FileNotFoundException;

public class BinaryProvider extends NativePluginProvider {

    @NotNull
    @Override
    public ParcelFileDescriptor openFile(@Nullable Uri uri) {
        try {
            return ParcelFileDescriptor.open(new File(getExecutable()), ParcelFileDescriptor.MODE_READ_ONLY);
        } catch (FileNotFoundException e) {
            throw new RuntimeException(e);
        }
    }

    @NotNull
    @Override
    public String getExecutable() {
        return getContext().getApplicationInfo().nativeLibraryDir + "/libgost-plugin.so";
    }

    @Override
    protected void populateFiles(@NotNull PathProvider provider) {
        provider.addPath("libgost-plugin", 0755);
    }
}