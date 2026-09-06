#include <QTest>
#include <zlib.h>

#include <GZip.h>
#include <random>

void fib(int& prev, int& cur)
{
    auto ret = prev + cur;
    prev = cur;
    cur = ret;
}

class GZipTest : public QObject {
    Q_OBJECT
   private slots:

    void test_Through()
    {
        // test up to 10 MB
        static const int size = 10 * 1024 * 1024;
        QByteArray random;
        QByteArray compressed;
        QByteArray decompressed;
        std::default_random_engine eng((std::random_device())());
        std::uniform_int_distribution<uint16_t> idis(0, std::numeric_limits<uint8_t>::max());

        // initialize random buffer
        for (int i = 0; i < size; i++) {
            random.append(static_cast<char>(idis(eng)));
        }

        // initialize fibonacci
        int prev = 1;
        int cur = 1;

        // test if fibonacci long random buffers pass through GZip
        do {
            QByteArray copy = random;
            copy.resize(cur);
            compressed.clear();
            decompressed.clear();
            QVERIFY(GZip::zip(copy, compressed));
            QVERIFY(GZip::unzip(compressed, decompressed));
            QCOMPARE(decompressed, copy);
            fib(prev, cur);
        } while (cur < size);
    }

    void test_InflateRaw()
    {
        QByteArray original = "{\"files\":[{\"projectID\":549404}],\"name\":\"Test Pack\"}";
        z_stream zs;
        memset(&zs, 0, sizeof(zs));
        deflateInit2(&zs, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY);
        zs.next_in = (Bytef*)original.data();
        zs.avail_in = original.size();
        QByteArray compressed(original.size() * 2 + 64, 0);
        zs.next_out = (Bytef*)compressed.data();
        zs.avail_out = compressed.size();
        deflate(&zs, Z_FINISH);
        compressed.resize(zs.total_out);
        deflateEnd(&zs);

        QByteArray uncompressed;
        QVERIFY(GZip::inflateRaw(compressed, uncompressed));
        QCOMPARE(uncompressed, original);
    }
};

QTEST_GUILESS_MAIN(GZipTest)

#include "GZip_test.moc"
