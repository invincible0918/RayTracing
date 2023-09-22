using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RadixSortTest : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        int[] array = { 53, 3, 542, 748, 14, 214 };
        //Debug.Log("Before Sort: " + string.Join(' ', array));
        //Sort(array);
        //Debug.Log("After Sort: " + string.Join(' ', array));

        array = new int[1000];
        for (int i = 0; i < array.Length; ++i)
            array[i] = (int)(Random.value * array.Length);
        Debug.Log("Before Sort: " + string.Join(' ', array));
        Sort(array);
        Debug.Log("After Sort: " + string.Join(' ', array));
    }

    void Sort(int[] arr)
    {
        // 1. 得到数组中的最大位数
        // 找出数组中最大的数
        int max = arr[0];
        for (int i = 1; i < arr.Length; i++)
        {
            if (arr[i] > max)
                max = arr[i];
        }

        // 得到最大数是第几位
        int maxLength = (max + "").Length;

        // 2. 开始排序
        // 定义一个2维数组，表示10个桶，每个桶就是一个1维数组
        // 说明：
        // 1. 2维数组包含10个1维数组
        // 2. 为了防止在放入的时候，数据溢出，每一个1维数据，大小定为arr.length
        int[,] bucket = new int[10, arr.Length];

        // bucketElementCounts[0]，就是bucket[0]的桶放入数据的个数
        int[] bucketElementCounts = new int[10];
        
        // 遍历从低位到高位，每次步进 10 * n
        for (int i = 0, n = 1; i < maxLength; i++, n *= 10)
        {
            // 针对每个元素的对应位进行排序，第一次循环是个位，第二次是十位。。。
            for (int j = 0; j < arr.Length; j++)
            {
                int digitOfElement = arr[j] / n % 10;
                bucket[digitOfElement, bucketElementCounts[digitOfElement]] = arr[j];
                bucketElementCounts[digitOfElement]++;
            }

            // 按照每个桶的顺序，遍历每个桶
            int index = 0;
            for (int k = 0; k < bucketElementCounts.Length; k++)
            {
                if (bucketElementCounts[k] != 0)
                {
                    for (int l = 0; l < bucketElementCounts[k]; l++)
                    {
                        arr[index++] = bucket[k, l];
                    }
                }
                bucketElementCounts[k] = 0;
            }

            // 其中一个位的循环结束
            //Debug.Log("Sort " + i + ": " + string.Join(' ', arr));
        }
    }

}
