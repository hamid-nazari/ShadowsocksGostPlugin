package com.github.shadowsocks.plugin.gost;

import android.net.Uri;
import android.os.ParcelFileDescriptor;
import com.github.shadowsocks.plugin.NativePluginProvider;
import com.github.shadowsocks.plugin.PathProvider;

import org.jetbrains.annotations.NonNls;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.io.File;
import java.io.FileNotFoundException;

public class NativeProvider extends NativePluginProvider {

    @NonNls
    public static final String NATIVE_PLUGIN_NAME = "libgost-plugin.so";
    @NonNls
    public static final String NATIVE_PATH = "gost_ssand_files";

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
        return getContext().getApplicationInfo().nativeLibraryDir + "/" + NATIVE_PLUGIN_NAME;
    }

    @Override
    protected void populateFiles(@NotNull PathProvider provider) {
        provider.addPath(NATIVE_PATH, 0755);
    }
}
